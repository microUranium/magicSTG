# GdUnit generated TestSuite
class_name AttackWarningConfigTest
extends GdUnitTestSuite
@warning_ignore("unused_variable")
@warning_ignore("unused_parameter")

# TestSuite generated from
const __source = "res://scripts/core/AttackWarningConfig.gd"


func test_default_values():
  # Given
  var config = AttackWarningConfig.new()

  # Then
  assert_that(config.base_color).is_equal(Color("#801919"))
  assert_that(config.glow_width).is_equal(8.0)
  assert_that(config.outline_width).is_equal(2.0)
  assert_that(config.warning_duration).is_equal(1.0)
  assert_that(config.glow_intensity).is_equal(2.0)
  assert_that(config.warning_length).is_equal(500.0)
  assert_that(config.angle_degrees).is_equal(0.0)
  assert_that(config.position_offset).is_equal(Vector2.ZERO)
  assert_that(config.use_relative_position).is_equal(true)


func test_angle_degrees_property():
  # Given
  var config = AttackWarningConfig.new()

  # When
  config.angle_degrees = 45.0

  # Then
  assert_that(config.angle_degrees).is_equal(45.0)


func test_position_offset_property():
  # Given
  var config = AttackWarningConfig.new()
  var offset = Vector2(10, 20)

  # When
  config.position_offset = offset

  # Then
  assert_that(config.position_offset).is_equal(offset)


func test_use_relative_position_property():
  # Given
  var config = AttackWarningConfig.new()

  # When - 絶対座標に設定
  config.use_relative_position = false

  # Then
  assert_that(config.use_relative_position).is_equal(false)


func test_visual_properties():
  # Given
  var config = AttackWarningConfig.new()

  # When
  config.base_color = Color.RED
  config.glow_width = 16.0
  config.outline_width = 4.0
  config.glow_intensity = 3.0

  # Then
  assert_that(config.base_color).is_equal(Color.RED)
  assert_that(config.glow_width).is_equal(16.0)
  assert_that(config.outline_width).is_equal(4.0)
  assert_that(config.glow_intensity).is_equal(3.0)


func test_timing_properties():
  # Given
  var config = AttackWarningConfig.new()

  # When
  config.warning_duration = 2.5
  config.warning_length = 1000.0

  # Then
  assert_that(config.warning_duration).is_equal(2.5)
  assert_that(config.warning_length).is_equal(1000.0)


func test_multiple_warning_line_configuration():
  # Given
  var config1 = AttackWarningConfig.new()
  var config2 = AttackWarningConfig.new()
  var config3 = AttackWarningConfig.new()

  # When - 複数方向の警告線設定
  config1.angle_degrees = 0.0  # 正面
  config1.position_offset = Vector2.ZERO

  config2.angle_degrees = 45.0  # 右斜め上
  config2.position_offset = Vector2(10, 0)

  config3.angle_degrees = -45.0  # 右斜め下
  config3.position_offset = Vector2(-10, 0)

  # Then
  assert_that(config1.angle_degrees).is_equal(0.0)
  assert_that(config2.angle_degrees).is_equal(45.0)
  assert_that(config3.angle_degrees).is_equal(-45.0)
  assert_that(config1.position_offset).is_equal(Vector2.ZERO)
  assert_that(config2.position_offset).is_equal(Vector2(10, 0))
  assert_that(config3.position_offset).is_equal(Vector2(-10, 0))


func test_relative_vs_absolute_positioning():
  # Given
  var relative_config = AttackWarningConfig.new()
  var absolute_config = AttackWarningConfig.new()

  # When
  relative_config.use_relative_position = true
  relative_config.position_offset = Vector2(50, 50)

  absolute_config.use_relative_position = false
  absolute_config.position_offset = Vector2(100, 100)

  # Then
  assert_that(relative_config.use_relative_position).is_true()
  assert_that(absolute_config.use_relative_position).is_false()
  assert_that(relative_config.position_offset).is_equal(Vector2(50, 50))
  assert_that(absolute_config.position_offset).is_equal(Vector2(100, 100))
