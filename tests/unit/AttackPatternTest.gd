# === AttackPattern のテスト ===
extends GdUnitTestSuite
class_name AttackPatternTest

var attack_pattern: AttackPattern


func before_test():
  attack_pattern = AttackPattern.new()


func test_default_values():
  """デフォルト値のテスト"""
  assert_that(attack_pattern.pattern_type).is_equal(AttackPattern.PatternType.SINGLE_SHOT)
  assert_that(attack_pattern.target_group).is_equal("players")
  assert_that(attack_pattern.damage).is_equal(5)
  assert_that(attack_pattern.bullet_count).is_equal(1)
  assert_that(attack_pattern.direction_type).is_equal(AttackPattern.DirectionType.TO_PLAYER)
  assert_that(attack_pattern.movement_type).is_equal(AttackPattern.MovementType.STRAIGHT)


func test_direction_calculation_fixed():
  """固定方向の計算テスト"""
  attack_pattern.direction_type = AttackPattern.DirectionType.FIXED
  attack_pattern.base_direction = Vector2.RIGHT

  var from_pos = Vector2(0, 0)
  var target_pos = Vector2(0, 100)  # 上方向（無視される）

  var direction = attack_pattern.calculate_base_direction(from_pos, target_pos)
  assert_that(direction).is_equal(Vector2.RIGHT)


func test_direction_calculation_to_player():
  """プレイヤー狙い方向の計算テスト"""
  attack_pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER

  var from_pos = Vector2(0, 0)
  var target_pos = Vector2(100, 100)

  var direction = attack_pattern.calculate_base_direction(from_pos, target_pos)
  var expected = (target_pos - from_pos).normalized()

  assert_that(direction.distance_to(expected)).is_less(0.01)


func test_direction_calculation_random():
  """ランダム方向の計算テスト"""
  attack_pattern.direction_type = AttackPattern.DirectionType.RANDOM

  var from_pos = Vector2(0, 0)
  var target_pos = Vector2(100, 100)

  # ランダムなので複数回テストして範囲内かチェック
  for i in range(10):
    var direction = attack_pattern.calculate_base_direction(from_pos, target_pos)
    assert_that(abs(direction.length() - 1.0)).is_less(0.01)  # 単位ベクトルであること


func test_circle_direction_calculation():
  """円形配置の弾丸方向計算テスト"""
  var base_dir = Vector2.DOWN
  var bullet_count = 8

  var directions = []
  for i in range(bullet_count):
    var dir = attack_pattern.calculate_circle_direction(i, bullet_count, base_dir)
    directions.append(dir)

  # 各方向が単位ベクトルであることを確認
  for dir in directions:
    assert_that(abs(dir.length() - 1.0)).is_less(0.01)

  # 8発の場合、45度ずつ配置される
  var angle_step = TAU / bullet_count
  for i in range(bullet_count):
    var expected_angle = angle_step * i
    var expected_dir = base_dir.rotated(expected_angle)
    assert_that(directions[i].distance_to(expected_dir)).is_less(0.01)


func test_spread_direction_calculation():
  """扇状配置の弾丸方向計算テスト"""
  attack_pattern.angle_spread = 60.0  # 60度の扇状
  var base_dir = Vector2.DOWN
  var bullet_count = 3

  var directions = []
  for i in range(bullet_count):
    var dir = attack_pattern.calculate_spread_direction(i, bullet_count, base_dir)
    directions.append(dir)

  # 各方向が単位ベクトルであることを確認
  for dir in directions:
    assert_that(abs(dir.length() - 1.0)).is_less(0.01)

  assert_that(directions.size()).is_equal(3)

  # 中央の弾丸は基準方向と同じはず
  var middle_index = bullet_count / 2
  assert_that(directions[middle_index].distance_to(base_dir)).is_less(0.01)


func test_spread_direction_single_bullet():
  """単発の場合の扇状配置テスト"""
  attack_pattern.angle_spread = 90.0
  var base_dir = Vector2.DOWN
  var bullet_count = 1

  var direction = attack_pattern.calculate_spread_direction(0, bullet_count, base_dir)

  # 単発の場合は基準方向と同じはず
  assert_that(direction).is_equal(base_dir)


func test_angle_offset_application():
  """角度オフセットの適用テスト"""
  attack_pattern.angle_offset = 45.0  # 45度オフセット
  var base_dir = Vector2.DOWN
  var bullet_count = 4

  var directions = []
  for i in range(bullet_count):
    var dir = attack_pattern.calculate_circle_direction(i, bullet_count, base_dir)
    directions.append(dir)

  # 最初の弾丸は base_dir を 45度回転したものになるはず
  var expected_first = base_dir.rotated(deg_to_rad(45.0))
  assert_that(directions[0].distance_to(expected_first)).is_less(0.01)


func test_composite_pattern_detection():
  """複合パターンの検出テスト"""
  # 通常のパターン
  assert_that(attack_pattern.is_composite_pattern()).is_false()

  # レイヤーを追加
  var layer1 = AttackPattern.new()
  layer1.pattern_type = AttackPattern.PatternType.SINGLE_SHOT

  attack_pattern.pattern_layers = [layer1]
  assert_that(attack_pattern.is_composite_pattern()).is_true()

  # 空の配列
  attack_pattern.pattern_layers = []
  assert_that(attack_pattern.is_composite_pattern()).is_false()


func test_pattern_layer_configuration():
  """パターンレイヤー設定のテスト"""
  var layer1 = AttackPattern.new()
  layer1.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  layer1.bullet_count = 3

  var layer2 = AttackPattern.new()
  layer2.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  layer2.rapid_fire_count = 2

  attack_pattern.pattern_layers = [layer1, layer2]
  attack_pattern.layer_delays = [0.0, 0.5]

  assert_that(attack_pattern.pattern_layers.size()).is_equal(2)
  assert_that(attack_pattern.layer_delays.size()).is_equal(2)
  assert_that(attack_pattern.layer_delays[1]).is_equal(0.5)
  assert_that(attack_pattern.is_composite_pattern()).is_true()


func test_custom_parameters():
  """カスタムパラメータのテスト"""
  attack_pattern.custom_parameters = {"test_param": 42, "test_string": "hello"}

  assert_that(attack_pattern.custom_parameters.has("test_param")).is_true()
  assert_that(attack_pattern.custom_parameters["test_param"]).is_equal(42)
  assert_that(attack_pattern.custom_parameters["test_string"]).is_equal("hello")


func test_beam_configuration():
  """ビーム設定のテスト"""
  attack_pattern.pattern_type = AttackPattern.PatternType.BEAM
  attack_pattern.beam_duration = 2.5
  attack_pattern.continuous_damage = true

  assert_that(attack_pattern.beam_duration).is_equal(2.5)
  assert_that(attack_pattern.continuous_damage).is_true()


func test_barrier_bullet_configuration():
  """バリア弾設定のテスト"""
  attack_pattern.pattern_type = AttackPattern.PatternType.BARRIER_BULLETS
  attack_pattern.circle_radius = 120.0
  attack_pattern.rotation_speed = 180.0
  attack_pattern.rotation_duration = 4.0

  assert_that(attack_pattern.circle_radius).is_equal(120.0)
  assert_that(attack_pattern.rotation_speed).is_equal(180.0)
  assert_that(attack_pattern.rotation_duration).is_equal(4.0)
