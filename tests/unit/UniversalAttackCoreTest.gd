# === UniversalAttackCore のテスト ===
extends GdUnitTestSuite
class_name UniversalAttackCoreTest

var universal_core: TestableUniversalAttackCore
var test_pattern: AttackPattern
var test_scene: Node2D
var owner_actor: Node2D


func before_test():
  test_scene = Node2D.new()
  add_child(test_scene)

  owner_actor = Node2D.new()
  owner_actor.global_position = Vector2(100, 100)
  test_scene.add_child(owner_actor)

  # テスト専用クラスを使用（PackedSceneの問題を回避）
  universal_core = TestableUniversalAttackCore.new()
  test_scene.add_child(universal_core)
  universal_core.set_owner_actor(owner_actor)

  # シンプルなテストパターン
  test_pattern = AttackPattern.new()
  test_pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  test_pattern.bullet_count = 3
  test_pattern.damage = 10
  test_pattern.bullet_speed = 200.0

  # テスト用のダミー弾丸シーンを作成
  var dummy_bullet = BulletStub.new()
  var packed_bullet_scene := PackedScene.new()
  packed_bullet_scene.pack(dummy_bullet)
  test_pattern.bullet_scene = packed_bullet_scene


func after_test():
  test_scene.queue_free()


func test_single_shot_execution():
  """単発射撃の実行テスト（修正版）"""
  universal_core.attack_pattern = test_pattern

  var success = await universal_core._execute_single_shot(test_pattern)

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)


func test_rapid_fire_execution():
  """連射の実行テスト（修正版）"""
  test_pattern.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  test_pattern.rapid_fire_count = 3
  test_pattern.rapid_fire_interval = 0.1
  universal_core.attack_pattern = test_pattern

  universal_core.clear_spawned_bullets()

  var start_time = Time.get_time_dict_from_system()["second"]
  var success = await universal_core._execute_rapid_fire(test_pattern)
  var end_time = Time.get_time_dict_from_system()["second"]

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(9)  # 3発 × 3回

  var duration = end_time - start_time
  assert_that(duration).is_greater_equal(0.2)  # 最低限の時間


func test_firing_condition_validation():
  """発射条件の検証テスト（修正版）"""
  # パターンが設定されていない場合
  universal_core.attack_pattern = null
  var is_valid = universal_core._validate_firing_conditions()
  assert_that(is_valid).is_false()

  # オーナーが設定されていない場合
  universal_core.attack_pattern = test_pattern
  universal_core.set_owner_actor(null)
  is_valid = universal_core._validate_firing_conditions()
  assert_that(is_valid).is_false()

  # 正常な場合
  universal_core.set_owner_actor(owner_actor)
  is_valid = universal_core._validate_firing_conditions()
  assert_that(is_valid).is_true()


func test_spiral_pattern_execution():
  """螺旋パターンの実行テスト"""
  # コア状態をリセット
  universal_core._cooling = false
  universal_core._paused = false

  test_pattern.pattern_type = AttackPattern.PatternType.SPIRAL
  test_pattern.bullet_count = 8
  universal_core.attack_pattern = test_pattern

  universal_core.clear_spawned_bullets()

  var success = await universal_core._execute_spiral(test_pattern)

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(8)


func test_barrier_bullets_pattern():
  """バリア弾パターンのテスト"""
  # コア状態をリセット（前のテストの影響を除去）
  universal_core._cooling = false
  universal_core._paused = false

  test_pattern.pattern_type = AttackPattern.PatternType.BARRIER_BULLETS
  test_pattern.bullet_count = 6
  test_pattern.circle_radius = 80.0
  test_pattern.rotation_duration = 2.0
  universal_core.attack_pattern = test_pattern

  universal_core.clear_spawned_bullets()

  var success = await universal_core._execute_barrier_bullets(test_pattern)

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(6)


func test_composite_pattern_execution():
  """複合パターンの実行テスト"""
  # コア状態をリセット
  universal_core._cooling = false
  universal_core._paused = false

  # レイヤー1: 単発射撃
  var layer1 = AttackPattern.new()
  layer1.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  layer1.bullet_count = 2
  layer1.damage = 5
  layer1.bullet_scene = test_pattern.bullet_scene

  # レイヤー2: 連射
  var layer2 = AttackPattern.new()
  layer2.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  layer2.bullet_count = 1
  layer2.rapid_fire_count = 2
  layer2.rapid_fire_interval = 0.05
  layer2.damage = 8
  layer2.bullet_scene = test_pattern.bullet_scene

  # 複合パターン作成
  var composite_pattern = AttackPattern.new()
  composite_pattern.pattern_layers.append(layer1)
  composite_pattern.pattern_layers.append(layer2)
  composite_pattern.layer_delays.append(0.0)
  composite_pattern.layer_delays.append(0.1)

  universal_core.attack_pattern = composite_pattern
  universal_core.clear_spawned_bullets()

  var success = await universal_core._execute_composite_pattern()

  assert_that(success).is_true()
  # レイヤー1: 2発 + レイヤー2: 2発 = 合計4発
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(4)


func test_direction_calculation():
  """方向計算のテスト"""
  # プレイヤー狙いの方向計算
  test_pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  var player_pos = Vector2(200, 200)
  var owner_pos = Vector2(100, 100)

  var direction = test_pattern.calculate_base_direction(owner_pos, player_pos)
  var expected = (player_pos - owner_pos).normalized()

  assert_that(direction.distance_to(expected)).is_less(0.01)

  # 固定方向の計算
  test_pattern.direction_type = AttackPattern.DirectionType.FIXED
  test_pattern.base_direction = Vector2.DOWN

  direction = test_pattern.calculate_base_direction(owner_pos, player_pos)
  assert_that(direction).is_equal(Vector2.DOWN)


func test_circle_direction_calculation():
  """円形配置の方向計算テスト"""
  var base_dir = Vector2.DOWN
  var bullet_count = 4

  # 各弾丸の方向を計算
  var directions = []
  for i in range(bullet_count):
    var dir = test_pattern.calculate_circle_direction(i, bullet_count, base_dir)
    directions.append(dir)

  # 4発の場合、90度ずつ配置されるはず
  assert_that(directions.size()).is_equal(4)

  # 各方向が単位ベクトルであることを確認
  for dir in directions:
    assert_that(abs(dir.length() - 1.0)).is_less(0.01)


func test_spread_direction_calculation():
  """扇状配置の方向計算テスト"""
  test_pattern.angle_spread = 90.0  # 90度の扇状
  var base_dir = Vector2.DOWN
  var bullet_count = 3

  var directions = []
  for i in range(bullet_count):
    var dir = test_pattern.calculate_spread_direction(i, bullet_count, base_dir)
    directions.append(dir)

  assert_that(directions.size()).is_equal(3)

  # 各方向が単位ベクトルであることを確認
  for dir in directions:
    assert_that(abs(dir.length() - 1.0)).is_less(0.01)
