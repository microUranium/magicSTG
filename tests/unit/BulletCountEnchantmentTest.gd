# === 増弾エンチャント（bullet_count_add）機能テスト ===
# テスト対象:
#   1. エンチャントの表示名・説明・ティア値（弾数 / 扇の角度）
#   2. ファクトリー経由で弾数と扇の角度（angle_spread）が反映されること
#   3. 角度は prototype.attack_pattern を基準にし、再計算しても加算が重ならないこと
#   4. prototype 側の attack_pattern（.tres の実体）を書き換えないこと
#   5. 反映後のパターンで弾が扇状に広がること
extends GdUnitTestSuite

const ENCHANT_PATH := "res://resources/data/enchantment_bullet_count_add.tres"
const MAGIC_BULLET_PATH := "res://resources/data/attackcore_magic_bullet.tres"
const FIREBALL_PATH := "res://resources/data/attackcore_fireball.tres"
const BOOMERANG_PATH := "res://resources/data/attackcore_boomerang.tres"

const COUNT_ADD := {1: 2, 2: 4, 3: 8}
const SPREAD_ADD := {1: 20.0, 2: 40.0, 3: 60.0}


func _make_pattern(core_path: String, level: int) -> AttackPattern:
  var proto: AttackCoreItem = load(core_path)
  var inst := ItemInstance.new(proto)
  if level > 0:
    inst.add_enchantment(load(ENCHANT_PATH), level)
  var pattern := PlayerAttackPatternFactory.create_pattern_from_item_instance(inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  return pattern


func test_enchantment_text() -> void:
  var enchant: Enchantment = load(ENCHANT_PATH)

  assert_str(str(enchant.id)).is_equal("bullet_count_add")
  assert_str(enchant.display_name).is_equal("増弾")
  assert_str(enchant.description).is_equal("発射する弾数が増えます。")


func test_enchantment_tier_values() -> void:
  var enchant: Enchantment = load(ENCHANT_PATH)

  for level in [1, 2, 3]:
    var mods := enchant.get_modifiers(level)
    assert_int(int(mods["bullet_count_add"])).is_equal(COUNT_ADD[level])
    assert_float(float(mods["angle_spread_add"])).is_equal_approx(SPREAD_ADD[level], 0.01)


func test_magic_bullet_count_and_spread_per_level() -> void:
  for level in [1, 2, 3]:
    var pattern := _make_pattern(MAGIC_BULLET_PATH, level)
    assert_int(pattern.bullet_count).is_equal(1 + COUNT_ADD[level])
    assert_float(pattern.angle_spread).is_equal_approx(SPREAD_ADD[level], 0.01)


func test_fireball_count_and_spread_per_level() -> void:
  for level in [1, 2, 3]:
    var pattern := _make_pattern(FIREBALL_PATH, level)
    assert_int(pattern.bullet_count).is_equal(1 + COUNT_ADD[level])
    assert_float(pattern.angle_spread).is_equal_approx(SPREAD_ADD[level], 0.01)


func test_without_enchantment_keeps_base_spread() -> void:
  var magic := _make_pattern(MAGIC_BULLET_PATH, 0)
  assert_int(magic.bullet_count).is_equal(1)
  assert_float(magic.angle_spread).is_equal_approx(0.0, 0.0001)

  var boomerang := _make_pattern(BOOMERANG_PATH, 0)
  var proto: AttackCoreItem = load(BOOMERANG_PATH)
  assert_float(boomerang.angle_spread).is_equal_approx(proto.attack_pattern.angle_spread, 0.0001)


func test_spread_is_added_to_core_base_angle() -> void:
  """基本の角度を持つコア（ブーメラン）は基本角度 + 加算値になる"""
  var proto: AttackCoreItem = load(BOOMERANG_PATH)
  var pattern := _make_pattern(BOOMERANG_PATH, 2)

  assert_float(pattern.angle_spread).is_equal_approx(
    proto.attack_pattern.angle_spread + SPREAD_ADD[2], 0.01
  )


func test_spread_update_is_idempotent() -> void:
  """再計算のたびに角度が加算されていかないこと"""
  var proto: AttackCoreItem = load(MAGIC_BULLET_PATH)
  var inst := ItemInstance.new(proto)
  inst.add_enchantment(load(ENCHANT_PATH), 3)
  var pattern := PlayerAttackPatternFactory.create_pattern_from_item_instance(inst)

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)

  assert_float(pattern.angle_spread).is_equal_approx(SPREAD_ADD[3], 0.01)


func test_prototype_pattern_is_not_modified() -> void:
  var proto: AttackCoreItem = load(MAGIC_BULLET_PATH)
  var spread_before := proto.attack_pattern.angle_spread

  _make_pattern(MAGIC_BULLET_PATH, 3)

  assert_float(proto.attack_pattern.angle_spread).is_equal_approx(spread_before, 0.0001)


func test_bullets_fan_out_symmetrically() -> void:
  """Lv3 のエネルギーショットは正面を中心に ±30° の扇へ均等に広がる"""
  var pattern := _make_pattern(MAGIC_BULLET_PATH, 3)
  var base_dir := Vector2.UP
  var angles: Array[float] = []
  for i in pattern.bullet_count:
    var dir := pattern.calculate_spread_direction(i, pattern.bullet_count, base_dir)
    angles.append(rad_to_deg(base_dir.angle_to(dir)))

  assert_float(angles.front()).is_equal_approx(-30.0, 0.01)
  assert_float(angles.back()).is_equal_approx(30.0, 0.01)
  var step := 60.0 / (pattern.bullet_count - 1)
  for i in range(1, angles.size()):
    assert_float(angles[i] - angles[i - 1]).is_equal_approx(step, 0.01)
