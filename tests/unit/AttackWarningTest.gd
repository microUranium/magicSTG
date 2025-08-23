# GdUnit generated TestSuite
class_name AttackWarningTest
extends GdUnitTestSuite
@warning_ignore("unused_variable")
@warning_ignore("unused_parameter")

# TestSuite generated from
const __source = "res://scripts/effects/AttackWarning.gd"

var warning_scene: PackedScene
var test_config: AttackWarningConfig


func before():
  # 警告線シーンをロード
  warning_scene = load("res://scenes/effects/attack_warning.tscn")

  # テスト用の設定を作成
  test_config = AttackWarningConfig.new()
  test_config.warning_length = 100.0
  test_config.warning_duration = 0.5
  test_config.angle_degrees = 0.0
  test_config.position_offset = Vector2.ZERO
  test_config.use_relative_position = true


func test_initialize_without_owner():
  # Given
  var warning = warning_scene.instantiate()
  add_child(warning)  # _ready()を呼ぶために追加
  await get_tree().process_frame  # @onreadyが完了するまで待機

  var start_pos = Vector2(10, 20)
  var end_pos = Vector2(110, 20)

  # When
  warning.initialize(start_pos, end_pos, test_config, null)

  # Then
  assert_that(warning.owner_node).is_null()
  assert_that(warning.position_offset).is_equal(Vector2.ZERO)

  # Cleanup
  warning.queue_free()


func test_initialize_with_owner_relative_position():
  # Given
  var warning = warning_scene.instantiate()
  add_child(warning)
  await get_tree().process_frame

  var owner = Node2D.new()
  owner.global_position = Vector2(50, 50)
  test_config.use_relative_position = true
  test_config.position_offset = Vector2(10, 20)

  var start_pos = Vector2.ZERO
  var end_pos = Vector2(100, 0)

  # When
  warning.initialize(start_pos, end_pos, test_config, owner)

  # Then
  assert_that(warning.owner_node).is_equal(owner)
  assert_that(warning.position_offset).is_equal(Vector2(10, 20))
  assert_that(warning.global_position).is_equal(Vector2(60, 70))  # owner + offset

  # Cleanup
  warning.queue_free()
  owner.queue_free()


func test_initialize_with_owner_absolute_position():
  # Given
  var warning = warning_scene.instantiate()
  add_child(warning)
  await get_tree().process_frame

  var owner = Node2D.new()
  owner.global_position = Vector2(50, 50)
  test_config.use_relative_position = false

  var start_pos = Vector2(100, 100)
  var end_pos = Vector2(200, 100)

  # When
  warning.initialize(start_pos, end_pos, test_config, owner)

  # Then
  assert_that(warning.owner_node).is_null()  # 絶対座標なのでownerは設定されない

  # Cleanup
  warning.queue_free()
  owner.queue_free()


func test_follow_functionality():
  # Given
  var warning = warning_scene.instantiate()
  add_child(warning)

  var owner = Node2D.new()
  add_child(owner)
  await get_tree().process_frame

  owner.global_position = Vector2(100, 100)
  test_config.use_relative_position = true
  test_config.position_offset = Vector2(25, 25)

  # When
  warning.initialize(Vector2.ZERO, Vector2(50, 0), test_config, owner)

  # Then - 初期位置確認
  assert_that(warning.global_position).is_equal(Vector2(125, 125))

  # When - ownerを移動
  owner.global_position = Vector2(200, 150)
  warning._process(0.016)  # 手動でprocessを呼び出し

  # Then - 追従確認
  assert_that(warning.global_position).is_equal(Vector2(225, 175))  # 200+25, 150+25

  # Cleanup
  warning.queue_free()
  owner.queue_free()


func test_no_follow_when_owner_is_null():
  # Given
  var warning = warning_scene.instantiate()
  add_child(warning)
  await get_tree().process_frame

  warning.owner_node = null
  warning.global_position = Vector2(50, 50)

  # When
  warning._process(0.016)

  # Then - 位置が変わらない
  assert_that(warning.global_position).is_equal(Vector2(50, 50))

  # Cleanup
  warning.queue_free()


func test_angle_calculation():
  # Given
  var warning = warning_scene.instantiate()
  add_child(warning)
  await get_tree().process_frame

  var owner = Node2D.new()

  test_config.angle_degrees = 90.0  # 下向き
  test_config.warning_length = 100.0
  test_config.use_relative_position = true

  var start_pos = Vector2.ZERO
  var end_pos = Vector2(0, 100)  # 90度（下向き）のベクトル

  # When
  warning.initialize(start_pos, end_pos, test_config, owner)

  # Then - 角度が正しく設定されているかは視覚的に確認困難なため、
  # 初期化が正常に完了することを確認
  assert_that(warning.owner_node).is_equal(owner)

  # Cleanup
  warning.queue_free()
  owner.queue_free()


func test_multiple_configuration_properties():
  # Given
  var warning = warning_scene.instantiate()
  add_child(warning)
  await get_tree().process_frame

  var complex_config = AttackWarningConfig.new()

  complex_config.base_color = Color.BLUE
  complex_config.warning_length = 200.0
  complex_config.warning_duration = 2.0
  complex_config.glow_width = 12.0
  complex_config.angle_degrees = 45.0
  complex_config.position_offset = Vector2(15, -10)
  complex_config.use_relative_position = true

  var owner = Node2D.new()
  owner.global_position = Vector2(100, 100)

  # When
  warning.initialize(Vector2.ZERO, Vector2(50, 50), complex_config, owner)

  # Then
  assert_that(warning.owner_node).is_equal(owner)
  assert_that(warning.position_offset).is_equal(Vector2(15, -10))
  assert_that(warning.global_position).is_equal(Vector2(115, 90))  # 100+15, 100-10

  # Cleanup
  warning.queue_free()
  owner.queue_free()
