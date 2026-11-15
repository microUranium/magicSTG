# === 後方射撃の切り替えで、発射中のビームの向きが変わることのテスト ===
# 本物の UniversalAttackCore とプレイヤーのビーム（beam.tscn = UniversalBeam）を使う。
# テスト対象:
#   1. 上向きのビームを発射中に後方射撃へ切り替えると下向きになり、下にいる敵に当たる
#   2. 切り替えてもビームは作り直されず、持続時間の残りも変わらない
#   3. 後方射撃を戻すと上向きに戻る
#   4. ビームを発射していないときに切り替えてもエラーにならない
extends GdUnitTestSuite

const PLAYER_BEAM_SCENE := "res://scenes/attackCores/player/beam.tscn"

var _core: UniversalAttackCore
var _owner_actor: Node2D
var _bullet_parent: Node2D


class DamageCounterEnemy:
  extends Area2D
  var taken := 0

  func take_damage(amount: int) -> void:
    taken += amount


func before_test() -> void:
  _bullet_parent = auto_free(Node2D.new())
  add_child(_bullet_parent)
  TargetService.set_bullet_parent(_bullet_parent)

  _owner_actor = auto_free(Node2D.new())
  add_child(_owner_actor)
  _owner_actor.global_position = Vector2(200, 500)

  var pattern := AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.BEAM
  pattern.beam_scene = load(PLAYER_BEAM_SCENE)
  pattern.beam_duration = 5.0  # テスト中に消えないよう長めに
  pattern.beam_offset = Vector2.ZERO
  pattern.damage = 3
  pattern.target_group = "enemies"
  pattern.direction_type = AttackPattern.DirectionType.FIXED
  pattern.base_direction = Vector2.UP

  _core = auto_free(UniversalAttackCore.new())
  _core.attack_pattern = pattern
  _core.auto_start = false
  add_child(_core)
  _core.set_owner_actor(_owner_actor)
  _core._cooling = false
  _core._paused = false


func after_test() -> void:
  TargetService.set_bullet_parent(null)


func _fire_beam() -> UniversalBeam:
  _core.trigger()
  await get_tree().process_frame
  assert_int(_core._active_beams.size()).is_equal(1)
  return _core._active_beams[0] as UniversalBeam


func _make_enemy(pos: Vector2) -> DamageCounterEnemy:
  var enemy := DamageCounterEnemy.new()
  var col := CollisionShape2D.new()
  var circle := CircleShape2D.new()
  circle.radius = 16.0
  col.shape = circle
  enemy.add_child(col)
  enemy.collision_layer = 3
  enemy.collision_mask = 0
  enemy.add_to_group("enemies")
  add_child(enemy)
  auto_free(enemy)
  enemy.global_position = pos
  return enemy


func test_toggle_rear_firing_turns_active_beam_down() -> void:
  var enemy_below := _make_enemy(Vector2(200, 800))
  var beam := await _fire_beam()
  assert_float(Vector2.UP.rotated(beam.rotation).distance_to(Vector2.UP)).is_less(0.001)

  _core.set_rear_firing_mode(true)

  assert_vector(beam.beam_direction).is_equal(Vector2.DOWN)
  assert_float(Vector2.UP.rotated(beam.rotation).distance_to(Vector2.DOWN)).is_less(0.001)

  await get_tree().physics_frame
  await get_tree().physics_frame
  beam._process(0.0)
  assert_array(beam._hits).contains_exactly([enemy_below])


func test_toggle_keeps_beam_and_remaining_duration() -> void:
  var beam := await _fire_beam()
  var remaining_before := _core._beam_duration_timer.time_left

  _core.set_rear_firing_mode(true)

  assert_object(_core._active_beams[0]).is_same(beam)  # 作り直していない
  assert_float(_core._beam_duration_timer.time_left).is_equal_approx(remaining_before, 0.05)


func test_toggle_back_returns_beam_up() -> void:
  var beam := await _fire_beam()

  _core.set_rear_firing_mode(true)
  _core.set_rear_firing_mode(false)

  assert_vector(beam.beam_direction).is_equal(Vector2.UP)


func test_toggle_without_active_beam_is_safe() -> void:
  _core.set_rear_firing_mode(true)

  assert_array(_core._active_beams).is_empty()
  assert_bool(_core._rear_firing_mode).is_true()


func test_multiple_beams_fan_out_and_all_flip() -> void:
  """増弾で増えた複数のビームは扇状に並び、後方射撃の切り替えで全部向きが変わる"""
  _core.attack_pattern.bullet_count = 3
  _core.attack_pattern.angle_spread = 20.0
  _core.trigger()
  await get_tree().process_frame
  assert_int(_core._active_beams.size()).is_equal(3)

  var angles: Array[float] = []
  for beam in _core._active_beams:
    angles.append(rad_to_deg(Vector2.UP.angle_to(beam.beam_direction)))
  assert_float(angles[0]).is_equal_approx(-10.0, 0.01)
  assert_float(angles[1]).is_equal_approx(0.0, 0.01)
  assert_float(angles[2]).is_equal_approx(10.0, 0.01)

  _core.set_rear_firing_mode(true)

  for beam in _core._active_beams:
    assert_float(beam.beam_direction.y).is_greater(0.9)  # 全部下向き
