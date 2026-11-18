# === 扇状ビームの警告線（AttackWarningConfig.angle_offset_degrees）と enemy_bird_d のビームのテスト ===
# テスト対象:
#   1. 警告線は攻撃の基準方向から angle_offset_degrees だけずれた向きに出る
#   2. 扇状の3本のビームと、ずらした3本の警告線の向きが揃う
#   3. angle_degrees（従来の項目）は警告線の向きに影響しない
#   4. enemy_bird_d のビームパターンの設定値
extends GdUnitTestSuite

const BIRD_D := "res://scenes/enemy/enemy_bird_d.tscn"


## 向きだけ記録するビーム
class StubBeam:
  extends Area2D
  var dir := Vector2.ZERO

  func initialize(_actor, _damage, direction, _beam_offset = Vector2.ZERO):
    dir = direction

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
  _owner_actor.global_position = Vector2(300, 200)

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


func _warning(offset_deg: float, absolute_deg := 0.0) -> AttackWarningConfig:
  var w := AttackWarningConfig.new()
  w.warning_duration = 0.1
  w.angle_offset_degrees = offset_deg
  w.angle_degrees = absolute_deg
  return w


## 真下（固定方向）へ、30°の扇で3本のビームを撃つコア
func _add_fan_core(warnings: Array) -> void:
  var pattern := AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.BEAM
  pattern.beam_scene = _beam_scene
  pattern.beam_duration = 5.0
  pattern.auto_start = false
  pattern.bullet_count = 3
  pattern.angle_spread = 30.0
  pattern.direction_type = AttackPattern.DirectionType.FIXED
  pattern.base_direction = Vector2.DOWN
  pattern.warning_configs.assign(warnings)

  _core = UniversalAttackCore.new()
  _core.attack_pattern = pattern
  _core.auto_start = false
  _scene.add_child(_core)
  _core.set_owner_actor(_owner_actor)


func _angle_deg(v: Vector2) -> float:
  return rad_to_deg(v.angle())


func test_warnings_are_rotated_by_offset_and_match_beams() -> void:
  _add_fan_core([_warning(-15.0), _warning(0.0), _warning(15.0)])

  _core.trigger()
  await await_millis(30)
  assert_int(_core._active_warnings.size()).is_equal(3)
  var warning_angles := []
  for w in _core._active_warnings:
    warning_angles.append(_angle_deg(w.rect_direction))
  warning_angles.sort()
  # 真下（90°）から -15° / 0 / +15°
  assert_float(warning_angles[0]).is_equal_approx(75.0, 0.01)
  assert_float(warning_angles[1]).is_equal_approx(90.0, 0.01)
  assert_float(warning_angles[2]).is_equal_approx(105.0, 0.01)

  # 警告線が終わると、同じ向きに3本のビームが出る
  await await_millis(200)
  assert_int(_core._active_beams.size()).is_equal(3)
  var beam_angles := []
  for b in _core._active_beams:
    beam_angles.append(_angle_deg(b.dir))
  beam_angles.sort()
  for i in 3:
    assert_float(beam_angles[i]).is_equal_approx(warning_angles[i], 0.01)


func test_angle_degrees_does_not_rotate_warning() -> void:
  # 従来の angle_degrees は絶対角度として設定されている箇所がある（ふぐ: 90）ため、向きには使わない
  _add_fan_core([_warning(0.0, 45.0)])

  _core.trigger()
  await await_millis(30)
  assert_float(_angle_deg(_core._active_warnings[0].rect_direction)).is_equal_approx(90.0, 0.01)


func test_bird_d_has_fan_beam_pattern() -> void:
  var bird: Node = auto_free(load(BIRD_D).instantiate())
  var slot = bird.get_node("AttackCoreSlot")
  var beams := (slot.attack_patterns_additive as Array).filter(
    func(p): return p.pattern_type == AttackPattern.PatternType.BEAM
  )
  assert_int(beams.size()).is_equal(1)

  var beam: AttackPattern = beams[0]
  assert_int(beam.direction_type).is_equal(AttackPattern.DirectionType.TO_PLAYER)
  assert_int(beam.bullet_count).is_equal(3)
  assert_float(beam.angle_spread).is_equal(30.0)
  assert_float(beam.burst_delay).is_equal(4.0)
  assert_float(beam.beam_duration).is_equal(3.0)
  assert_int(beam.damage).is_equal(1)
  assert_str(beam.beam_visual_config.texture.resource_path).is_equal(
    "res://assets/gfx/sprites/beam_enemy_sprite.png"
  )
  # シェーダーは切り出し範囲の 1/3 を 1 コマとして描くので、その横幅が見た目の幅と同じなら
  # 横方向が等倍になり、根元の丸い飾り（縦は等倍）が縦長に歪まない
  var beam_node: UniversalBeam = auto_free(beam.beam_scene.instantiate())
  assert_float(beam_node.get_node("NinePatchRect").region_rect.size.x / 3.0).is_equal(
    beam.beam_visual_config.width
  )

  var offsets := []
  for w in beam.warning_configs:
    assert_float(w.warning_duration).is_equal(1.0)
    offsets.append(w.angle_offset_degrees)
  offsets.sort()
  assert_array(offsets).is_equal([-15.0, 0.0, 15.0])

  # 既存の 8 方向 3 連射（3 重リング）は残っている
  var rings := (slot.attack_patterns_additive as Array).filter(
    func(p): return p.pattern_type == AttackPattern.PatternType.RAPID_FIRE
  )
  assert_int(rings.size()).is_equal(2)
  assert_int(slot.attack_pattern.pattern_type).is_equal(AttackPattern.PatternType.RAPID_FIRE)
