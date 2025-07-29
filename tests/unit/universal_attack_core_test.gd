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

  var packed_bullet_scene := PackedScene.new()
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
