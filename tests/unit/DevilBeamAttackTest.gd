# === 強化悪魔ボス phase5 のビーム攻撃のテスト ===
# テスト対象:
#   1. UniversalAttackCore.cancel_attack() が警告線・発射中のビームを消し、警告線の待ち中の発射も止める
#   2. ScreenHalfVerticalDirection が画面の上半分なら下向き、下半分なら上向きを返す
#   3. 悪魔ビーム（8 倍）の当たり判定の帯は画面上で 128px、見た目は中心に揃い自機で止まる
#   4. ボスのビームパターンの設定値
extends GdUnitTestSuite

const DEVIL_BEAM_SCENE := "res://scenes/attackCores/enemy/enemy_beam_devil.tscn"
const SCREEN_HALF_VERTICAL_DIRECTION := preload(
  "res://scripts/enemy/ScreenHalfVerticalDirection.gd"
)


## 何もしないビーム（UniversalAttackCore._execute_beam が呼ぶメソッドだけ持つ）
class StubBeam:
  extends Area2D

  func initialize(_actor, _damage, _direction, _beam_offset = Vector2.ZERO):
    pass

  func set_target_group(_group: String):
    pass


var _scene: Node2D
var _owner_actor: Node2D
var _core: UniversalAttackCore
var _beam_scene: PackedScene


func before_test() -> void:
  _scene = Node2D.new()
  add_child(_scene)
  _owner_actor = Node2D.new()
  _scene.add_child(_owner_actor)

  var stub := StubBeam.new()
  _beam_scene = PackedScene.new()
  _beam_scene.pack(stub)
  stub.free()


func after_test() -> void:
  if is_instance_valid(_core):
    for node in _core._active_warnings + _core._active_beams:
      if is_instance_valid(node):
        node.free()
  _scene.free()


func _add_beam_core(beam_duration: float, warning_duration: float = 0.0) -> void:
  var pattern := AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.BEAM
  pattern.beam_scene = _beam_scene
  pattern.beam_duration = beam_duration
  pattern.auto_start = false  # trigger() だけを検証する
  if warning_duration > 0.0:
    var warning := AttackWarningConfig.new()
    warning.warning_duration = warning_duration
    pattern.warning_configs = [warning]

  _core = UniversalAttackCore.new()
  _core.attack_pattern = pattern
  _core.auto_start = false
  _scene.add_child(_core)
  _core.set_owner_actor(_owner_actor)


func test_cancel_during_warning_removes_warning_and_does_not_fire() -> void:
  _add_beam_core(5.0, 0.3)

  _core.trigger()  # 警告線を出して待ちに入る
  await await_millis(50)
  assert_int(_core._active_warnings.size()).is_equal(1)
  var warning: Node = _core._active_warnings[0]

  _core.cancel_attack()
  await await_idle_frame()
  assert_bool(is_instance_valid(warning)).is_false()
  assert_array(_core._active_warnings).is_empty()

  # 警告線の待ち時間が過ぎてもビームは出ない
  await await_millis(400)
  assert_array(_core._active_beams).is_empty()
  assert_array(_core._spawned_projectiles).is_empty()
  assert_bool(_core._firing).is_false()


func test_cancel_during_beam_removes_beam() -> void:
  _add_beam_core(5.0)

  _core.trigger()
  await await_idle_frame()
  assert_int(_core._active_beams.size()).is_equal(1)
  var beam: Node = _core._active_beams[0]

  _core.cancel_attack()
  await await_idle_frame()
  assert_bool(is_instance_valid(beam)).is_false()
  assert_array(_core._active_beams).is_empty()


func test_finished_warning_is_removed_from_tracking() -> void:
  _add_beam_core(5.0, 0.1)

  _core.trigger()
  await await_millis(300)

  # 警告線は自分で消え、追跡からも外れる。その後ビームが出る
  assert_array(_core._active_warnings).is_empty()
  assert_int(_core._active_beams.size()).is_equal(1)


func test_direction_is_down_in_upper_half_and_up_in_lower_half() -> void:
  var center_y := PlayArea.get_play_rect().get_center().y

  var upper: Vector2 = SCREEN_HALF_VERTICAL_DIRECTION.calculate_direction(
    Vector2(100, center_y - 100), Vector2.ZERO, {}
  )
  var lower: Vector2 = SCREEN_HALF_VERTICAL_DIRECTION.calculate_direction(
    Vector2(100, center_y + 100), Vector2.ZERO, {}
  )

  assert_vector(upper).is_equal(Vector2.DOWN)
  assert_vector(lower).is_equal(Vector2.UP)


## 自機役の当たり判定（layer 1）
class DamageCounter:
  extends Area2D
  var taken := 0

  func take_damage(amount: int) -> void:
    taken += amount


func _place_player(pos: Vector2, radius: float) -> DamageCounter:
  var player := DamageCounter.new()
  var col := CollisionShape2D.new()
  var circle := CircleShape2D.new()
  circle.radius = radius
  col.shape = circle
  player.add_child(col)
  player.collision_layer = 1
  player.collision_mask = 0
  player.add_to_group("players")
  _scene.add_child(player)
  player.global_position = pos
  return player


## ボスのパターンの見た目設定（8 倍）を当てた悪魔ビームを (400, 100) から下向きに撃つ
func _fire_devil_beam_down() -> UniversalBeam:
  var ai: BossDevilEnhancedAI = auto_free(BossDevilEnhancedAI.new())
  var pattern := ai.create_phase3_beam_pattern()
  _owner_actor.global_position = Vector2(400, 100)

  var beam: UniversalBeam = load(DEVIL_BEAM_SCENE).instantiate()
  _scene.add_child(beam)
  beam.dmg_timer.stop()
  beam.initialize(_owner_actor, pattern.damage, Vector2.DOWN, pattern.beam_offset)
  beam.set_target_group(pattern.target_group)
  beam.apply_visual_config(pattern.beam_visual_config)
  await get_tree().physics_frame
  await get_tree().physics_frame
  beam._process(0.0)
  return beam


func test_devil_beam_hit_band_is_128px_on_screen() -> void:
  # 帯の半幅 64px + 自機の半径 8px = 中心から 72px 未満なら当たる
  var inside := _place_player(Vector2(400 + 60, 500), 8.0)
  var beam := await _fire_devil_beam_down()
  assert_array(beam._hits).contains_exactly([inside])

  inside.global_position = Vector2(400 + 90, 500)
  await get_tree().physics_frame
  await get_tree().physics_frame
  beam._process(0.0)
  assert_array(beam._hits).is_empty()


func test_devil_beam_visual_is_centered_and_stops_at_player() -> void:
  _place_player(Vector2(400, 500), 8.0)
  var beam := await _fire_devil_beam_down()

  # 見た目（切り出した 64px × 8 倍 = 512px）はビームの中心に揃う
  # ビームは下向きで 180° 回転しているので、ローカルの矩形を画面座標に変換して比べる
  var rect: Rect2 = beam.ninepatch.get_global_transform() * Rect2(Vector2.ZERO, beam.ninepatch.size)
  assert_float(rect.get_center().x).is_equal_approx(400.0, 1.0)
  assert_float(rect.size.x).is_equal_approx(512.0, 1.0)
  # 見た目の長さも自機の上端（y = 492）で止まる
  assert_float(rect.end.y).is_equal_approx(492.0, 2.0)

  beam._on_damage_tick()
  var player := beam._hits[0] as DamageCounter
  assert_int(player.taken).is_equal(2)


func test_boss_beam_pattern_settings() -> void:
  var ai: BossDevilEnhancedAI = auto_free(BossDevilEnhancedAI.new())
  var pattern := ai.create_phase3_beam_pattern()

  assert_int(pattern.pattern_type).is_equal(AttackPattern.PatternType.BEAM)
  assert_int(pattern.damage).is_equal(2)
  assert_float(pattern.beam_duration).is_equal(5.0)
  assert_float(pattern.burst_delay).is_equal(5.0)
  assert_int(pattern.direction_type).is_equal(AttackPattern.DirectionType.CUSTOM)
  assert_object(pattern.custom_script).is_same(SCREEN_HALF_VERTICAL_DIRECTION)
  assert_vector(pattern.beam_visual_config.scale).is_equal(Vector2(8, 8))
  assert_int(pattern.warning_configs.size()).is_equal(1)
  assert_float(pattern.warning_configs[0].warning_duration).is_equal(2.0)
  assert_float(pattern.warning_configs[0].glow_width).is_equal(128.0)
  assert_float(pattern.warning_configs[0].outline_width).is_equal(128.0)
