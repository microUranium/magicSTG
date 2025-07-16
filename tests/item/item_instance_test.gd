extends GdUnitTestSuite

var _proto: BlessingItem
var _enc: Enchantment


func _before() -> void:
  _proto = BlessingItem.new()
  _proto.id = "proto_test"
  _proto.display_name = "テスト加護"
  _proto.base_modifiers = {}

  var tier: EnchantmentTier = EnchantmentTier.new()
  tier.level = 1
  tier.modifiers = {"hp_bonus": 10}

  _enc = Enchantment.new()
  _enc.id = "enc_test"
  _enc.display_name = "テストエンチャント"
  _enc.tiers = [tier]


# "quantity は常に 1"
func test_quantity_always_one() -> void:
  var inst := ItemInstance.new(_proto)
  assert_int(inst.get_quantity()).is_equal(1)


# "add_enchantment() で配列追加 & シグナル発火")
func test_add_enchantment() -> void:
  var inst := ItemInstance.new(_proto)
  var emitter := monitor_signals(inst)

  inst.add_enchantment(_enc, 1)

  await assert_signal(emitter).wait_until(50).is_emitted("enchantment_added", [_enc, 1])
  assert_int(inst.enchantments.size()).is_equal(1)
  assert_object(inst.enchantments.keys()[0]).is_equal(_enc)
  assert_int(inst.enchantments.values()[0]).is_equal(1)
