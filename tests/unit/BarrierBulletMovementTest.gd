# === BarrierBulletMovement のテスト ===
extends GdUnitTestSuite
class_name BarrierBulletMovementTest

var movement_config: BarrierBulletMovement


func before_test():
  movement_config = BarrierBulletMovement.new()


func test_default_values():
  """デフォルト値のテスト"""
  assert_that(movement_config.orbit_radius).is_equal(100.0)
  assert_that(movement_config.approach_duration).is_equal(0.5)
  assert_that(movement_config.orbit_duration).is_equal(3.0)
  assert_that(movement_config.rotation_speed).is_equal(90.0)
  assert_that(movement_config.rotate_during_approach).is_false()
  assert_that(movement_config.projectile_direction_type).is_equal(
    BarrierBulletMovement.ProjectileDirection.TO_TARGET
  )
  assert_that(movement_config.projectile_speed).is_equal(200.0)


func test_spread_direction_type():
  """SPREAD方向タイプの設定テスト"""
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.SPREAD

  assert_that(movement_config.projectile_direction_type).is_equal(
    BarrierBulletMovement.ProjectileDirection.SPREAD
  )


func test_rotate_during_approach_enabled():
  """rotate_during_approachの有効化テスト"""
  movement_config.rotate_during_approach = true

  assert_that(movement_config.rotate_during_approach).is_true()


func test_all_projectile_direction_types():
  """全ProjectileDirection値が設定できることのテスト"""
  var types = [
    BarrierBulletMovement.ProjectileDirection.TO_TARGET,
    BarrierBulletMovement.ProjectileDirection.CURRENT_VELOCITY,
    BarrierBulletMovement.ProjectileDirection.FIXED,
    BarrierBulletMovement.ProjectileDirection.RANDOM,
    BarrierBulletMovement.ProjectileDirection.SPREAD,
  ]

  for dir_type in types:
    movement_config.projectile_direction_type = dir_type
    assert_that(movement_config.projectile_direction_type).is_equal(dir_type)


func test_config_duplication_preserves_new_fields():
  """duplicate()で新規フィールドが保持されるテスト"""
  movement_config.rotate_during_approach = true
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.SPREAD
  movement_config.orbit_radius = 150.0

  var copy = movement_config.duplicate()

  assert_that(copy.rotate_during_approach).is_true()
  assert_that(copy.projectile_direction_type).is_equal(
    BarrierBulletMovement.ProjectileDirection.SPREAD
  )
  assert_that(copy.orbit_radius).is_equal(150.0)
