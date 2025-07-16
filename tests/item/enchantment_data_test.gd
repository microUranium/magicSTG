extends GdUnitTestSuite


func test_get_modifiers_returns_expected_tier() -> void:
  var tier1 := EnchantmentTier.new()
  tier1.level = 1
  tier1.modifiers = {"damage_add": 10}

  var tier2 := EnchantmentTier.new()
  tier2.level = 2
  tier2.modifiers = {"damage_add": 20}

  var data := Enchantment.new()
  data.id = "dummy"
  data.display_name = "Dummy"
  data.tiers = [tier1, tier2]

  assert_dict(data.get_modifiers(1)).is_equal({"damage_add": 10})
  assert_dict(data.get_modifiers(2)).is_equal({"damage_add": 20})
  # 範囲外 → 端にクランプされる仕様
  assert_dict(data.get_modifiers(99)).is_equal({"damage_add": 20})
