# === 弾の有効時間・初速のランダム範囲指定のテスト ===
extends GdUnitTestSuite

const SAMPLES := 200


func test_lifetime_is_fixed_when_max_is_unset() -> void:
  var pattern := AttackPattern.new()
  pattern.bullet_lifetime = 1.25

  for i in SAMPLES:
    assert_float(pattern.roll_bullet_lifetime()).is_equal(1.25)


func test_lifetime_is_fixed_when_max_is_not_greater() -> void:
  var pattern := AttackPattern.new()
  pattern.bullet_lifetime = 2.0
  pattern.bullet_lifetime_max = 1.0

  assert_float(pattern.roll_bullet_lifetime()).is_equal(2.0)


func test_lifetime_is_random_within_range() -> void:
  var pattern := AttackPattern.new()
  pattern.bullet_lifetime = 2.5
  pattern.bullet_lifetime_max = 3.5

  var seen_low := false
  var seen_high := false
  for i in SAMPLES:
    var value := pattern.roll_bullet_lifetime()
    assert_float(value).is_between(2.5, 3.5)
    seen_low = seen_low or value < 3.0
    seen_high = seen_high or value >= 3.0
  # 範囲の片側に張り付いていないこと
  assert_bool(seen_low and seen_high).is_true()


func test_initial_speed_is_fixed_when_max_is_unset() -> void:
  var config := BulletMovementConfig.new()
  config.initial_speed = 400.0

  for i in SAMPLES:
    assert_float(config.roll_initial_speed()).is_equal(400.0)


func test_initial_speed_is_random_within_range() -> void:
  var config := BulletMovementConfig.new()
  config.initial_speed = 150.0
  config.initial_speed_max = 600.0

  var seen_low := false
  var seen_high := false
  for i in SAMPLES:
    var value := config.roll_initial_speed()
    assert_float(value).is_between(150.0, 600.0)
    seen_low = seen_low or value < 375.0
    seen_high = seen_high or value >= 375.0
  assert_bool(seen_low and seen_high).is_true()


func test_bullet_speed_is_rolled_when_movement_config_applied() -> void:
  var config := BulletMovementConfig.new()
  config.movement_type = BulletMovementConfig.MovementType.DECELERATE
  config.initial_speed = 150.0
  config.initial_speed_max = 600.0

  var bullet = auto_free(load("res://scenes/bullets/universal_bullet.tscn").instantiate())
  add_child(bullet)
  bullet.direction = Vector2.DOWN
  bullet.apply_movement_config(config)

  assert_float(bullet.speed).is_between(150.0, 600.0)
