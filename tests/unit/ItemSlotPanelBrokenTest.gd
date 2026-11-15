class_name ItemSlotPanelBrokenTest
extends GdUnitTestSuite

const ItemInstanceStubScript := preload("res://tests/stubs/ItemInstanceStub.gd")
const ItemPanelScene := preload("res://scenes/ui/item_panel.tscn")
const MAGIC_BROKEN := preload("res://assets/gfx/sprites/magic_broken_sprite.png")
const BLESSING_BROKEN := preload("res://assets/gfx/sprites/blessing_broken_sprite.png")


func _make_slot(item: ItemInstance) -> ItemSlotPanel:
  var slot: ItemSlotPanel = auto_free(ItemPanelScene.instantiate())
  var d := ItemPanelData.new()
  d.inst = item
  slot.data = d
  add_child(slot)
  return slot


func _item(item_type: ItemBase.ItemType, broken: bool) -> ItemInstance:
  var item: ItemInstance = ItemInstanceStubScript.dummy_item("item", item_type)
  item.is_broken = broken
  return item


func _drop_payload() -> Dictionary:
  return {"type": "item", "inst": _item(ItemBase.ItemType.ATTACK_CORE, false), "src": null}


func test_normal_item_shows_own_icon() -> void:
  var item := _item(ItemBase.ItemType.ATTACK_CORE, false)
  var slot := _make_slot(item)

  assert_object(slot.icon.texture).is_same(item.prototype.icon)
  assert_that(slot.frame.modulate).is_equal(item.get_rarity_color())
  assert_that(slot.modulate).is_equal(Color.WHITE)
  assert_bool(slot.is_broken()).is_false()


func test_broken_attack_core_uses_magic_broken_sprite() -> void:
  var slot := _make_slot(_item(ItemBase.ItemType.ATTACK_CORE, true))

  assert_object(slot.icon.texture).is_same(MAGIC_BROKEN)


func test_broken_blessing_uses_blessing_broken_sprite() -> void:
  var slot := _make_slot(_item(ItemBase.ItemType.BLESSING, true))

  assert_object(slot.icon.texture).is_same(BLESSING_BROKEN)


func test_broken_slot_is_grayed_out() -> void:
  var slot := _make_slot(_item(ItemBase.ItemType.ATTACK_CORE, true))

  assert_that(slot.frame.modulate).is_equal(ItemSlotPanel.BROKEN_FRAME_COLOR)
  assert_that(slot.modulate).is_equal(ItemSlotPanel.BROKEN_MODULATE)


func test_broken_slot_cannot_be_dragged() -> void:
  var slot := _make_slot(_item(ItemBase.ItemType.ATTACK_CORE, true))

  assert_that(slot._get_drag_data(Vector2.ZERO)).is_null()


func test_broken_slot_rejects_drop() -> void:
  var slot := _make_slot(_item(ItemBase.ItemType.ATTACK_CORE, true))

  assert_bool(slot._can_drop_data(Vector2.ZERO, _drop_payload())).is_false()


func test_normal_slot_accepts_drop() -> void:
  var slot := _make_slot(_item(ItemBase.ItemType.ATTACK_CORE, false))

  assert_bool(slot._can_drop_data(Vector2.ZERO, _drop_payload())).is_true()


func test_broken_slot_does_not_show_tooltip() -> void:
  var slot := _make_slot(_item(ItemBase.ItemType.ATTACK_CORE, true))
  # monitor_signals() は監視対象を auto_free するため、オートロードには直接接続して数える
  var shown: Array[ItemInstance] = []
  var on_show := func(item: ItemInstance): shown.append(item)
  EquipSignals.request_show_item.connect(on_show)

  slot._on_hover()
  EquipSignals.request_show_item.disconnect(on_show)

  assert_int(shown.size()).is_equal(0)
