extends GdUnitTestSuite


func test_roll_enchantments_respects_max_count() -> void:
  # ---- 事前準備 ---------------------------------------------------------
  LootSystem._rng.seed = 1  # 乱数を固定して再現性を確保

  var proto := ItemBase.new()
  var inst := ItemInstance.new(proto)

  var enc1 := Enchantment.new()
  var enc2 := Enchantment.new()

  var rule := EnchantmentRule.new()
  rule.count_weights = {1: 1.0}  # 1 個まで
  rule.pool = [enc1, enc2]  # 候補は 2 個
  rule.level_weights = {1: 1.0}  # レベル 1 のみ出る

  # ---- 実行 -------------------------------------------------------------
  LootSystem._roll_enchantments(inst, rule)  # private だがテストでは直接呼び出し OK

  # ---- 検証 -------------------------------------------------------------
  assert_int(inst.enchantments.size()).is_less_equal(1)
  if inst.enchantments.size() == 1:
    assert_array(rule.pool).contains(inst.enchantments.keys())


func _make_pool(size: int) -> Array[Enchantment]:
  var pool: Array[Enchantment] = []
  for i in size:
    var enc := Enchantment.new()
    enc.id = StringName("enc_%d" % i)
    pool.append(enc)
  return pool


func test_roll_enchantments_can_add_three() -> void:
  var inst := ItemInstance.new(ItemBase.new())

  var rule := EnchantmentRule.new()
  rule.count_weights = {3: 1.0}
  rule.level_weights = {3: 1.0}
  rule.pool = _make_pool(4)

  LootSystem._roll_enchantments(inst, rule)

  assert_int(inst.enchantments.size()).is_equal(3)
  # Lv3 × 3 個 = 合計 9 で最高ティアに届く
  assert_int(inst.get_rarity_tier()).is_equal(ItemInstance.RarityTier.LEGENDARY)


func test_roll_enchantments_clamps_count_to_max() -> void:
  var inst := ItemInstance.new(ItemBase.new())

  var rule := EnchantmentRule.new()
  rule.count_weights = {5: 1.0}  # 上限を超える個数
  rule.level_weights = {1: 1.0}
  rule.pool = _make_pool(5)

  LootSystem._roll_enchantments(inst, rule)

  assert_int(inst.enchantments.size()).is_equal(LootSystem.enchantment_max_count)


func test_roll_enchantments_stops_when_pool_runs_out() -> void:
  var inst := ItemInstance.new(ItemBase.new())

  var rule := EnchantmentRule.new()
  rule.count_weights = {3: 1.0}
  rule.level_weights = {1: 1.0}
  rule.pool = _make_pool(2)  # 候補が上限より少ない

  LootSystem._roll_enchantments(inst, rule)

  assert_int(inst.enchantments.size()).is_equal(2)
