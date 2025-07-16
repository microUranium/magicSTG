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
