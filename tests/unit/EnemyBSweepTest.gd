# === enemy_b の攻撃のテスト ===
# プレイヤーを中心に扇の範囲を、連射で1発ずつ掃くように撃つ（AttackPattern.sweep_spread）
extends GdUnitTestSuite

const ENEMY_B := preload("res://scenes/enemy/enemy_b.tscn")


func test_sweeps_around_player_with_rapid_fire() -> void:
  var enemy: Node = auto_free(ENEMY_B.instantiate())
  var pattern: AttackPattern = enemy.get_node("AttackCoreSlot").attack_pattern

  assert_int(pattern.pattern_type).is_equal(AttackPattern.PatternType.RAPID_FIRE)
  assert_int(pattern.rapid_fire_count).is_greater(1)
  assert_int(pattern.direction_type).is_equal(AttackPattern.DirectionType.TO_PLAYER)
  assert_float(pattern.angle_spread).is_greater(0.0)
  assert_bool(pattern.sweep_spread).is_true()
  assert_int(pattern.bullet_count).is_equal(1)
