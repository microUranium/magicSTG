extends GdUnitTestSuite

const SAVE_PATH := "res://resources/data/default_player_save.json"


func _make_enchantment(id: StringName) -> Enchantment:
  var enc := Enchantment.new()
  enc.id = id
  return enc


func _make_rule(pool: Array[Enchantment], count: int) -> EnchantmentRule:
  var rule := EnchantmentRule.new()
  rule.count_weights = {count: 1.0}
  rule.level_weights = {1: 1.0}
  rule.pool = pool
  return rule


func _enchant_ids(inst: ItemInstance) -> Array:
  return inst.enchantments.keys().map(func(enc: Enchantment) -> StringName: return enc.id)


## ---------- ItemBase.allows_enchantment ----------
func test_allows_any_enchantment_when_list_is_empty() -> void:
  var proto := ItemBase.new()

  assert_bool(proto.allows_enchantment(_make_enchantment(&"cooldown_pct"))).is_true()


func test_allows_only_listed_enchantments() -> void:
  var proto := ItemBase.new()
  proto.allowed_enchantments = [_make_enchantment(&"cooldown_pct")]

  assert_bool(proto.allows_enchantment(_make_enchantment(&"cooldown_pct"))).is_true()
  assert_bool(proto.allows_enchantment(_make_enchantment(&"shield_hp_pct"))).is_false()


func test_allows_duplicated_enchantment_by_id() -> void:
  var enc := _make_enchantment(&"cooldown_pct")
  var proto := ItemBase.new()
  proto.allowed_enchantments = [enc]

  # LootSystem は付与時に duplicate() するため、別インスタンスでも id が同じなら許可される
  assert_bool(proto.allows_enchantment(enc.duplicate())).is_true()


func test_rejects_null_enchantment() -> void:
  var proto := ItemBase.new()

  assert_bool(proto.allows_enchantment(null)).is_false()


## ---------- LootSystem._roll_enchantments ----------
func test_roll_excludes_enchantments_not_allowed_by_item() -> void:
  var allowed := _make_enchantment(&"cooldown_pct")
  var proto := ItemBase.new()
  proto.allowed_enchantments = [allowed]
  var inst := ItemInstance.new(proto)

  var rule := _make_rule([allowed, _make_enchantment(&"shield_hp_pct")], 2)
  LootSystem._roll_enchantments(inst, rule)

  # 2 個付与する設定でも、許可された 1 種しか付かない
  assert_array(_enchant_ids(inst)).contains_exactly([&"cooldown_pct"])


func test_roll_uses_whole_pool_when_item_has_no_restriction() -> void:
  var inst := ItemInstance.new(ItemBase.new())

  var rule := _make_rule(
    [_make_enchantment(&"cooldown_pct"), _make_enchantment(&"shield_hp_pct")], 2
  )
  LootSystem._roll_enchantments(inst, rule)

  assert_array(_enchant_ids(inst)).contains_exactly_in_any_order(
    [&"cooldown_pct", &"shield_hp_pct"]
  )


func test_roll_adds_nothing_when_no_pool_entry_is_allowed() -> void:
  var proto := ItemBase.new()
  proto.allowed_enchantments = [_make_enchantment(&"cooldown_pct")]
  var inst := ItemInstance.new(proto)

  var rule := _make_rule([_make_enchantment(&"shield_hp_pct")], 1)
  LootSystem._roll_enchantments(inst, rule)

  assert_int(inst.enchantments.size()).is_equal(0)


## ---------- データ整合性 ----------
func test_every_item_defines_allowed_enchantments() -> void:
  assert_int(ItemDb._items.size()).is_greater(0)
  for item: ItemBase in ItemDb._items.values():
    # 未設定だと全エンチャントが候補になり、効かないエンチャントが付く
    (
      assert_bool(item.allowed_enchantments.is_empty())
      . override_failure_message("%s has no allowed_enchantments" % item.id)
      . is_false()
    )
    for enc in item.allowed_enchantments:
      assert_object(enc).override_failure_message("%s has a null entry" % item.id).is_not_null()


func test_default_save_enchantments_are_allowed_by_their_items() -> void:
  var save = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
  assert_object(save).is_not_null()

  for entry in _collect_item_entries(save):
    var item := ItemDb.get_item_by_id(entry["id"])
    assert_object(item).override_failure_message("unknown item: %s" % entry["id"]).is_not_null()
    for e in entry["enchantments"]:
      var enc := ItemDb.get_enchantment_by_id(e["id"])
      (
        assert_bool(item.allows_enchantment(enc))
        . override_failure_message(
          "%s: %s is not allowed on %s" % [entry.get("uid", ""), e["id"], entry["id"]]
        )
        . is_true()
      )


func _collect_item_entries(node: Variant) -> Array:
  var result := []
  if node is Dictionary:
    if node.has("id") and node.has("enchantments"):
      result.append(node)
    for v in node.values():
      result.append_array(_collect_item_entries(v))
  elif node is Array:
    for v in node:
      result.append_array(_collect_item_entries(v))
  return result
