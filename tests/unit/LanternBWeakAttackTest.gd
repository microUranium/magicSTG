# === lantern_b_weak の攻撃のテスト ===
# テスト対象:
#   1. プレイヤー狙いで1発ずつ撃つ加速弾（boss_bird_swamp の分身の火の玉と同じ撃ち方）
#   2. 弾の見た目・軌跡パーティクル・爆発のパーティクルは lantern_b と同じ
#   3. 爆風のダメージはあるが、ダメージフィールドは残さない（lantern_b は残す）
#   4. 射程は lantern_b と同じ（射程の終わりで爆発する）
#   5. lantern_b の弾も同じ加速弾
# 数値は調整で変わるため、決め打ちせずに lantern_b のシーンと比べる
extends GdUnitTestSuite

const WEAK := preload("res://scenes/enemy/enemy_lantern_b_weak.tscn")
const LANTERN_B := preload("res://scenes/enemy/enemy_lantern_b.tscn")


func _pattern(scene: PackedScene) -> AttackPattern:
  var enemy: Node = auto_free(scene.instantiate())
  return enemy.get_node("AttackCoreSlot").attack_pattern


func test_fires_single_aimed_accelerating_bullet() -> void:
  var pattern := _pattern(WEAK)

  assert_int(pattern.direction_type).is_equal(AttackPattern.DirectionType.TO_PLAYER)
  assert_int(pattern.bullet_count).is_equal(1)
  assert_int(pattern.bullet_movement_config.movement_type).is_equal(
    BulletMovementConfig.MovementType.ACCELERATE
  )
  assert_bool(pattern.persist_offscreen).is_false()


func test_visual_and_effects_match_lantern_b() -> void:
  var weak := _pattern(WEAK).bullet_visual_config
  var base := _pattern(LANTERN_B).bullet_visual_config

  assert_object(weak.texture).is_same(base.texture)
  assert_bool(weak.enable_particles).is_true()
  assert_object(weak.particle_material).is_not_null()
  assert_object(weak.explosion_config).is_not_null()
  assert_bool(weak.explosion_config.enable_particles).is_true()
  assert_object(weak.explosion_config.explosion_particle_material).is_not_null()


func test_explosion_damages_but_leaves_no_field() -> void:
  var explosion := _pattern(WEAK).bullet_visual_config.explosion_config

  assert_int(explosion.explosion_damage).is_greater(0)
  assert_float(explosion.explosion_radius).is_greater(0.0)
  assert_object(explosion.damage_field).is_null()
  # lantern_b のほうはフィールドを残す（こちらだけ外している）
  (
    assert_object(_pattern(LANTERN_B).bullet_visual_config.explosion_config.damage_field)
    . is_not_null()
  )


func test_range_matches_lantern_b() -> void:
  var weak := _pattern(WEAK)
  assert_float(weak.bullet_range).is_greater(0.0)
  assert_float(weak.bullet_range).is_equal(_pattern(LANTERN_B).bullet_range)


func test_lantern_b_fires_same_accelerating_bullet() -> void:
  var weak: BulletMovementConfig = _pattern(WEAK).bullet_movement_config
  var base: BulletMovementConfig = _pattern(LANTERN_B).bullet_movement_config

  assert_int(base.movement_type).is_equal(BulletMovementConfig.MovementType.ACCELERATE)
  assert_float(base.initial_speed).is_equal(weak.initial_speed)
  assert_float(base.acceleration_rate).is_equal(weak.acceleration_rate)
  assert_float(base.max_speed).is_equal(weak.max_speed)
