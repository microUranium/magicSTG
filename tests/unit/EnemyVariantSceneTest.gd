# === 雑魚敵の派生版（継承シーン）テスト ===
# 他ステージへ跨って登場させる強化版・弱体版が、元シーンからの差分だけを上書きしていることを確認する
extends GdUnitTestSuite

const LANTERN := "res://scenes/enemy/enemy_lantern.tscn"
const LANTERN_B := "res://scenes/enemy/enemy_lantern_b.tscn"
const LANTERN_B_WEAK := "res://scenes/enemy/enemy_lantern_b_weak.tscn"
const GRIMOIRE := "res://scenes/enemy/enemy_grimoire.tscn"
const GRIMOIRE_STRONG := "res://scenes/enemy/enemy_grimoire_strong.tscn"
const FLOWER_B := "res://scenes/enemy/enemy_flower_b.tscn"
const FLOWER_B_STRONG := "res://scenes/enemy/enemy_flower_b_strong.tscn"
const STAGE_DATA := "res://resources/data/stage_data.json"


func _instantiate(path: String) -> Node:
  var scene := load(path) as PackedScene
  assert_object(scene).is_not_null()
  return auto_free(scene.instantiate())


func _pattern(enemy: Node) -> AttackPattern:
  return enemy.get_node("AttackCoreSlot").attack_pattern


# --- enemy_lantern_b_weak（stage3 向け弱体版）---


func test_lantern_b_weak_slows_spiral_by_30_percent() -> void:
  var base_mc := _pattern(_instantiate(LANTERN_B)).bullet_movement_config
  var weak_mc := _pattern(_instantiate(LANTERN_B_WEAK)).bullet_movement_config

  # 螺旋弾は半径の広がりと回転の両方を 0.7 倍にして、軌道形状を保ったまま減速する
  assert_float(weak_mc.spiral_radius_growth).is_equal_approx(
    base_mc.spiral_radius_growth * 0.7, 0.01
  )
  assert_float(weak_mc.spiral_rotation_speed).is_equal_approx(
    base_mc.spiral_rotation_speed * 0.7, 0.01
  )
  assert_int(weak_mc.movement_type).is_equal(base_mc.movement_type)


func test_lantern_b_weak_has_same_hp_as_lantern() -> void:
  var lantern := _instantiate(LANTERN)
  var weak := _instantiate(LANTERN_B_WEAK)

  # stage3 の雑魚に合わせ、同ステージの enemy_lantern と同じ HP にする
  assert_int(weak.get_node("HpNode").max_hp).is_equal(lantern.get_node("HpNode").max_hp)


func test_lantern_b_weak_keeps_other_stats() -> void:
  var base := _instantiate(LANTERN_B)
  var weak := _instantiate(LANTERN_B_WEAK)

  assert_float(_pattern(weak).burst_delay).is_equal(_pattern(base).burst_delay)
  assert_int(_pattern(weak).bullet_count).is_equal(_pattern(base).bullet_count)
  assert_int(_pattern(weak).damage).is_equal(_pattern(base).damage)
  assert_str(weak.name).is_equal(base.name)


# --- enemy_grimoire_strong（stage5 向け強化版）---


func test_grimoire_strong_shortens_warp_interval() -> void:
  var base := _instantiate(GRIMOIRE)
  var strong := _instantiate(GRIMOIRE_STRONG)

  assert_float(strong.get_node("EnemyAI").warp_interval).is_equal_approx(
    base.get_node("EnemyAI").warp_interval * 0.75, 0.01
  )


func test_grimoire_strong_fires_three_spread_bullets() -> void:
  var pattern := _pattern(_instantiate(GRIMOIRE_STRONG))

  assert_int(pattern.bullet_count).is_equal(3)
  # 角度差がないと 3 発が重なって 1 発に見えるため、扇状に広げる
  assert_float(pattern.angle_spread).is_greater(0.0)


func test_grimoire_strong_homing_turns_more_gently() -> void:
  var base_mc := _pattern(_instantiate(GRIMOIRE)).bullet_movement_config
  var strong_mc := _pattern(_instantiate(GRIMOIRE_STRONG)).bullet_movement_config

  # 旋回が速いと扇状の弾がすぐ 1 点に収束してしまうため、追尾の角速度を緩める
  assert_int(strong_mc.movement_type).is_equal(base_mc.movement_type)
  assert_float(strong_mc.max_turn_angle_per_second).is_less(base_mc.max_turn_angle_per_second)


func test_grimoire_strong_bullets_are_15_percent_faster() -> void:
  var base := _pattern(_instantiate(GRIMOIRE))
  var strong := _pattern(_instantiate(GRIMOIRE_STRONG))

  # 実際の弾速は movement_config.initial_speed で上書きされるため両方を揃えて上げる
  assert_float(strong.bullet_movement_config.initial_speed).is_equal_approx(
    base.bullet_movement_config.initial_speed * 1.15, 0.01
  )
  assert_float(strong.bullet_speed).is_equal_approx(base.bullet_speed * 1.15, 0.01)


func test_grimoire_strong_keeps_other_stats() -> void:
  var base := _instantiate(GRIMOIRE)
  var strong := _instantiate(GRIMOIRE_STRONG)

  assert_int(_pattern(strong).damage).is_equal(_pattern(base).damage)
  assert_int(strong.get_node("HpNode").max_hp).is_equal(base.get_node("HpNode").max_hp)
  assert_object(_pattern(strong).bullet_visual_config.texture).is_same(
    _pattern(base).bullet_visual_config.texture
  )


# --- enemy_flower_b_strong（stage6 向け強化版）---


func test_flower_b_strong_has_500_hp() -> void:
  assert_int(_instantiate(FLOWER_B_STRONG).get_node("HpNode").max_hp).is_equal(500)


func test_flower_b_strong_keeps_upward_pattern_as_base() -> void:
  var base := _instantiate(FLOWER_B)
  var strong := _instantiate(FLOWER_B_STRONG)

  # 上向き攻撃は元シーンのパターンをそのまま継承する
  assert_object(_pattern(strong)).is_same(_pattern(base))


func test_flower_b_strong_adds_downward_pattern() -> void:
  var up := _pattern(_instantiate(FLOWER_B))
  var additive: Array = (
    _instantiate(FLOWER_B_STRONG).get_node("AttackCoreSlot").attack_patterns_additive
  )

  assert_int(additive.size()).is_equal(1)
  var down: AttackPattern = additive[0]

  # base_direction (0, 1) を反転させずに撃つ = 下向き
  assert_float(up.angle_offset).is_equal(180.0)
  assert_float(down.angle_offset).is_equal(0.0)
  assert_that(down.base_direction).is_equal(up.base_direction)
  # 下向きは破裂（寿命切れ）までの時間を短くする
  assert_float(down.bullet_lifetime).is_less(up.bullet_lifetime)
  assert_float(down.bullet_lifetime).is_equal_approx(0.65, 0.001)


func test_flower_b_strong_downward_pattern_matches_upward_otherwise() -> void:
  var up := _pattern(_instantiate(FLOWER_B))
  var down: AttackPattern = (
    _instantiate(FLOWER_B_STRONG).get_node("AttackCoreSlot").attack_patterns_additive[0]
  )

  assert_int(down.pattern_type).is_equal(up.pattern_type)
  assert_int(down.damage).is_equal(up.damage)
  assert_int(down.rapid_fire_count).is_equal(up.rapid_fire_count)
  assert_float(down.burst_delay).is_equal(up.burst_delay)
  assert_float(down.angle_spread).is_equal(up.angle_spread)
  assert_int(down.direction_type).is_equal(up.direction_type)
  assert_float(down.bullet_movement_config.initial_speed).is_equal(
    up.bullet_movement_config.initial_speed
  )
  assert_int(down.bullet_visual_config.explosion_config.explosion_damage).is_equal(
    up.bullet_visual_config.explosion_config.explosion_damage
  )


# --- stage_data.json への登録 ---


func test_variants_are_registered_in_stage_data() -> void:
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA))
  var enemies: Dictionary = data["enemies"]

  assert_str(enemies["enemy_lantern_b_weak"]["scene_path"]).is_equal(LANTERN_B_WEAK)
  assert_str(enemies["enemy_grimoire_strong"]["scene_path"]).is_equal(GRIMOIRE_STRONG)
  assert_str(enemies["enemy_flower_b_strong"]["scene_path"]).is_equal(FLOWER_B_STRONG)
