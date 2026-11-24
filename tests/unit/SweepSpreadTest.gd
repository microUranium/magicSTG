# === 連射で扇の範囲を掃く撃ち方（AttackPattern.sweep_spread）のテスト ===
# テスト対象:
#   1. sweep_spread の TO_PLAYER の連射は、撃ち始めのプレイヤーの向きを中心に angle_spread の範囲を1発ずつ掃く
#   2. 撃っている途中でプレイヤーが動いても、中心は撃ち始めの向きのまま
#   3. sweep_spread なしの TO_PLAYER の連射は、これまでどおり毎回プレイヤーを狙う（掃かない）
extends GdUnitTestSuite


## 弾を出す代わりに向きを記録する。プレイヤーの位置はテストから決める
class SpyCore:
  extends UniversalAttackCore
  var directions: Array[Vector2] = []
  var player_pos := Vector2.ZERO

  func _spawn_bullet(
    _pattern: AttackPattern, direction: Vector2, _spawn_pos: Vector2, _bullet_index: int = -1
  ) -> bool:
    directions.append(direction)
    return true

  func _execute_single_shot(_pattern: AttackPattern) -> bool:
    directions.append((player_pos - _owner_actor.global_position).normalized())
    return true

  func _get_player_position() -> Vector2:
    return player_pos


var _owner: Node2D
var _core: SpyCore


func before_test() -> void:
  _owner = Node2D.new()
  add_child(_owner)
  _owner.global_position = Vector2(400, 200)
  _core = SpyCore.new()
  _owner.add_child(_core)
  _core._owner_actor = _owner
  _core.player_pos = Vector2(400, 700)  # 真下


func after_test() -> void:
  _owner.free()


func _sweep_pattern() -> AttackPattern:
  var p := AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 12, 0.0, 3
  )
  p.direction_type = AttackPattern.DirectionType.TO_PLAYER
  p.angle_spread = 90
  p.sweep_spread = true
  return p


func test_sweeps_spread_around_player_direction() -> void:
  var pattern := _sweep_pattern()
  var to_player := (_core.player_pos - _owner.global_position).normalized()

  await _core._execute_rapid_fire(pattern)

  assert_int(_core.directions.size()).is_equal(pattern.rapid_fire_count)
  var half := deg_to_rad(pattern.angle_spread) / 2.0
  assert_float(to_player.angle_to(_core.directions[0])).is_equal_approx(-half, 0.001)
  assert_float(to_player.angle_to(_core.directions[-1])).is_equal_approx(half, 0.001)
  # 等間隔に掃く
  var step := deg_to_rad(pattern.angle_spread) / (pattern.rapid_fire_count - 1)
  for i in range(1, _core.directions.size()):
    assert_float(_core.directions[i - 1].angle_to(_core.directions[i])).is_equal_approx(step, 0.001)


func test_center_stays_at_start_direction_while_player_moves() -> void:
  var pattern := _sweep_pattern()
  pattern.rapid_fire_interval = 0.01
  var to_player := (_core.player_pos - _owner.global_position).normalized()

  var run := func() -> void: await _core._execute_rapid_fire(pattern)
  run.call()
  _core.player_pos = Vector2(900, 200)  # 撃っている途中で真横へ動く
  await await_millis(300)

  assert_int(_core.directions.size()).is_equal(pattern.rapid_fire_count)
  var half := deg_to_rad(pattern.angle_spread) / 2.0
  assert_float(to_player.angle_to(_core.directions[-1])).is_equal_approx(half, 0.001)


func test_without_sweep_aims_each_shot() -> void:
  var pattern := _sweep_pattern()
  pattern.sweep_spread = false
  var to_player := (_core.player_pos - _owner.global_position).normalized()

  await _core._execute_rapid_fire(pattern)

  for d in _core.directions:
    assert_vector(d).is_equal_approx(to_player, Vector2(0.001, 0.001))
