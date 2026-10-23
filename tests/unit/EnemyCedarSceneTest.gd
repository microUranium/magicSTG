# === enemy_cedar（スギ）のテスト ===
# 通常攻撃はせず、HP が 20% 減るごとに花粉を 50 発ばらまく（撃破時も含む）
extends GdUnitTestSuite

const LIVING_WOOD := "res://scenes/enemy/enemy_living_wood.tscn"
const CEDAR := "res://scenes/enemy/enemy_cedar.tscn"
const CEDAR_TEXTURE := "res://assets/gfx/sprites/enemy_cedar_sprite.png"
const POLLEN_TEXTURE := "res://assets/gfx/sprites/bullet_enemy_sprite_2.png"
const STAGE_DATA := "res://resources/data/stage_data.json"
const POLLEN_PER_BURST := 50

var _bullet_root: Node2D


func before_test() -> void:
  _bullet_root = auto_free(Node2D.new())
  add_child(_bullet_root)
  TargetService.set_bullet_parent(_bullet_root)


func after_test() -> void:
  TargetService.set_bullet_parent(null)


func _instantiate(path: String) -> Node:
  var scene := load(path) as PackedScene
  assert_object(scene).is_not_null()
  return auto_free(scene.instantiate())


func _spawn_cedar() -> Node:
  var cedar := _instantiate(CEDAR)
  # 撃破パーティクルは current_scene に追加されるが、テスト実行中は current_scene が無いため生成しない
  cedar.destroy_particles_scene = null
  add_child(cedar)
  await await_idle_frame()  # AttackCoreSlot がコアを生成するのを待つ
  return cedar


func _pollen() -> AttackPattern:
  return _instantiate(CEDAR).get_node("AttackCoreSlot").attack_pattern


# --- シーン構成 ---


func test_cedar_uses_cedar_sprite() -> void:
  var frames: SpriteFrames = _instantiate(CEDAR).get_node("AnimatedSprite2D").sprite_frames

  assert_int(frames.get_frame_count("default")).is_equal(2)
  for i in frames.get_frame_count("default"):
    var tex: AtlasTexture = frames.get_frame_texture("default", i)
    assert_str(tex.atlas.resource_path).is_equal(CEDAR_TEXTURE)


func test_cedar_has_same_hp_as_living_wood() -> void:
  var living_wood := _instantiate(LIVING_WOOD)
  var cedar := _instantiate(CEDAR)

  assert_int(cedar.get_node("HpNode").max_hp).is_equal(living_wood.get_node("HpNode").max_hp)


func test_cedar_has_no_shield() -> void:
  var cedar := _instantiate(CEDAR)

  assert_bool("shield_scene" in cedar).is_false()


func test_pollen_does_not_fire_automatically() -> void:
  assert_bool(_pollen().auto_start).is_false()


func test_pollen_scatters_50_bullets_in_random_directions() -> void:
  var pollen := _pollen()

  assert_int(pollen.pattern_type).is_equal(AttackPattern.PatternType.SINGLE_SHOT)
  assert_int(pollen.bullet_count).is_equal(POLLEN_PER_BURST)
  # RANDOM + angle_spread 0 で全方向ランダム
  assert_int(pollen.direction_type).is_equal(AttackPattern.DirectionType.RANDOM)
  assert_float(pollen.angle_spread).is_equal(0.0)


func test_pollen_uses_unscaled_sprite_with_8px_hitbox() -> void:
  var visual := _pollen().bullet_visual_config

  assert_str(visual.texture.resource_path).is_equal(POLLEN_TEXTURE)
  assert_float(visual.scale).is_equal(1.0)
  assert_float(visual.collision_radius).is_equal(8.0)


func test_pollen_lifetime_is_random_between_2_5_and_3_5_sec() -> void:
  var pollen := _pollen()

  assert_float(pollen.bullet_lifetime).is_equal(2.5)
  assert_float(pollen.bullet_lifetime_max).is_equal(3.5)


func test_pollen_decelerates_from_random_speed_and_keeps_drifting() -> void:
  var movement := _pollen().bullet_movement_config

  assert_int(movement.movement_type).is_equal(BulletMovementConfig.MovementType.DECELERATE)
  assert_float(movement.initial_speed_max).is_greater(movement.initial_speed)
  assert_float(movement.deceleration_rate).is_greater(0.0)
  # 止まりきらず、少しだけ流れ続ける
  assert_float(movement.min_speed).is_greater(0.0)


func test_cedar_is_registered_in_stage_data() -> void:
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA))

  assert_str(data["enemies"]["enemy_cedar"]["scene_path"]).is_equal(CEDAR)


# --- HP 20% ごとの発射 ---


func test_no_pollen_before_losing_20_percent() -> void:
  var cedar := await _spawn_cedar()

  cedar.get_node("HpNode").take_damage(99)  # 500 中 99 減 = 19.8%

  assert_int(_bullet_root.get_child_count()).is_equal(0)


func test_scatters_pollen_at_exactly_20_percent() -> void:
  var cedar := await _spawn_cedar()

  cedar.get_node("HpNode").take_damage(100)

  assert_int(_bullet_root.get_child_count()).is_equal(POLLEN_PER_BURST)


func test_scatters_once_per_threshold_crossed_by_single_hit() -> void:
  var cedar := await _spawn_cedar()

  cedar.get_node("HpNode").take_damage(210)  # 一撃で 20% と 40% を越える

  assert_int(_bullet_root.get_child_count()).is_equal(POLLEN_PER_BURST * 2)


func test_does_not_scatter_again_within_same_step() -> void:
  var cedar := await _spawn_cedar()
  var hp := cedar.get_node("HpNode")

  hp.take_damage(100)
  hp.take_damage(50)  # 30% 減。次の区切り（40%）には届いていない

  assert_int(_bullet_root.get_child_count()).is_equal(POLLEN_PER_BURST)


func test_scatters_five_times_including_defeat() -> void:
  var cedar := await _spawn_cedar()
  var hp := cedar.get_node("HpNode")

  for i in 5:
    hp.take_damage(100)

  # 20/40/60/80% と撃破時（100%）の計 5 回
  assert_int(_bullet_root.get_child_count()).is_equal(POLLEN_PER_BURST * 5)
  assert_bool(cedar.is_queued_for_deletion()).is_true()


func test_overkill_scatters_remaining_bursts() -> void:
  var cedar := await _spawn_cedar()

  cedar.get_node("HpNode").take_damage(9999)

  assert_int(_bullet_root.get_child_count()).is_equal(POLLEN_PER_BURST * 5)
