class_name EquipmentScreenTest
extends GdUnitTestSuite

const ItemInstanceStubScript := preload("res://tests/stubs/ItemInstanceStub.gd")

var screen: Control
var grid
var equipment_screen: EquipmentScreen
var inv_slot: ItemSlotPanel
var equip_slot: EquipSlotPanel


func before() -> void:
  screen = auto_free(preload("res://scenes/levels/equipment_root.tscn").instantiate())
  get_tree().root.add_child(screen)
  equipment_screen = get_tree().root.get_node("EquipmentScreen")
  equipment_screen._ready()  # 明示的に呼び出し

  await get_tree().process_frame  # UI 初期化待ち

  grid = screen.get_node("InventoryPanel/ItemListPane/InventoryGrid")
  var equip_slots = get_tree().get_nodes_in_group("equipment_slots")
  for slot in equip_slots:
    if slot is EquipSlotPanel:
      slot.data = null  # 既存の装備をクリア
      slot._refresh()  # スロットの見た目を更新

  # テスト用アイテムを仕込む
  var item_ac: ItemInstance = ItemInstanceStubScript.dummy_item(
    "core1", ItemBase.ItemType.ATTACK_CORE
  )
  var panel_data := ItemPanelData.new()
  panel_data.inst = item_ac
  var panel_list: Array[ItemPanelData] = [panel_data]
  grid.set_items(panel_list)

  await get_tree().process_frame  # UI 更新待ち


func test_swap_inventory_to_equip() -> void:
  inv_slot = grid.get_child(0) as ItemSlotPanel
  var equip_slots = get_tree().get_nodes_in_group("equipment_slots")
  for slot in equip_slots:
    if slot is EquipSlotPanel and slot.allowed_type == ItemBase.ItemType.ATTACK_CORE:
      equip_slot = slot
      break

  assert_bool(inv_slot.data != null).is_true()

  # swap_request を直接 emit
  EquipSignals.emit_signal("swap_request", inv_slot, equip_slot)
  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel

  assert_bool(equip_slot.data.inst != null).is_true()
  assert_str(equip_slot.data.inst.uid).is_equal("core1")
  assert_bool(inv_slot.data == null).is_true()


func test_right_click_returns_to_inventory() -> void:
  var equip_slots = get_tree().get_nodes_in_group("equipment_slots")
  for slot in equip_slots:
    if slot is EquipSlotPanel and slot.data != null:
      equip_slot = slot
      break

  var evt := InputEventMouseButton.new()
  evt.button_index = MOUSE_BUTTON_RIGHT
  evt.pressed = true

  equip_slot._gui_input(evt)

  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel

  assert_bool(inv_slot.data != null).is_true()
  assert_int(grid.get_items().size()).is_equal(1)  # アイテムがインベントリに戻っている
  assert_str(inv_slot.data.inst.uid).is_equal("core1")


func test_right_click_equips_to_empty_slot() -> void:
  # このテストは状態を自己完結で構築する（スイート内で before() は1回のみ実行のため）
  _reset_equipment_slots()
  _set_single_inventory_item("core1")
  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if slot is EquipSlotPanel and slot.allowed_type == ItemBase.ItemType.ATTACK_CORE:
      equip_slot = slot
      break

  assert_bool(inv_slot.data != null).is_true()
  assert_bool(equip_slot.data == null).is_true()  # 空きスロット

  inv_slot._gui_input(_right_click_event())

  await get_tree().process_frame

  # 空きスロットへ装備され、持ち物欄からは除去されている
  assert_bool(equip_slot.data != null).is_true()
  assert_str(equip_slot.data.inst.uid).is_equal("core1")
  assert_int(grid.get_items().size()).is_equal(0)


func test_right_click_does_nothing_when_no_empty_slot() -> void:
  _reset_equipment_slots()
  # ATTACK_CORE スロットを全て埋める
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if slot is EquipSlotPanel and slot.allowed_type == ItemBase.ItemType.ATTACK_CORE:
      var occupant := ItemPanelData.new()
      occupant.inst = ItemInstanceStubScript.dummy_item("occupant", ItemBase.ItemType.ATTACK_CORE)
      slot.data = occupant
      slot._refresh()
  _set_single_inventory_item("core1")
  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel
  assert_bool(inv_slot.data != null).is_true()

  inv_slot._gui_input(_right_click_event())

  await get_tree().process_frame

  # 空きが無いので持ち物欄に残る
  inv_slot = grid.get_child(0) as ItemSlotPanel
  assert_bool(inv_slot.data != null).is_true()
  assert_str(inv_slot.data.inst.uid).is_equal("core1")
  assert_int(grid.get_items().size()).is_equal(1)


func test_drop_equipped_onto_different_type_inventory_item_keeps_both() -> void:
  # 異種装備（加護）を、魔法が入った持ち物枠へドロップしても持ち物側が消えないこと
  _reset_equipment_slots()
  _set_single_inventory_item("core1")
  var blessing_slot := _find_equip_slot(ItemBase.ItemType.BLESSING)
  var blessing := ItemPanelData.new()
  blessing.inst = ItemInstanceStubScript.dummy_item("bless1", ItemBase.ItemType.BLESSING)
  blessing_slot.data = blessing
  blessing_slot._refresh()
  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel
  EquipSignals.emit_signal("swap_request", blessing_slot, inv_slot)
  await get_tree().process_frame

  # 加護は外れ、魔法は持ち物欄に残ったまま両方存在する
  assert_bool(blessing_slot.data == null).is_true()
  assert_int(grid.get_items().size()).is_equal(2)
  var uids: Array[String] = []
  for d in grid.get_items():
    uids.append(d.inst.uid)
  assert_array(uids).contains(["bless1", "core1"])


func test_drop_equipped_onto_same_type_inventory_item_swaps() -> void:
  # 同種装備はこれまで通り交換されること
  _reset_equipment_slots()
  _set_single_inventory_item("core1")
  var core_slot := _find_equip_slot(ItemBase.ItemType.ATTACK_CORE)
  var equipped := ItemPanelData.new()
  equipped.inst = ItemInstanceStubScript.dummy_item("core2", ItemBase.ItemType.ATTACK_CORE)
  core_slot.data = equipped
  core_slot._refresh()
  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel
  EquipSignals.emit_signal("swap_request", core_slot, inv_slot)
  await get_tree().process_frame

  assert_str(core_slot.data.inst.uid).is_equal("core1")
  assert_int(grid.get_items().size()).is_equal(1)
  assert_str(grid.get_items()[0].inst.uid).is_equal("core2")


func test_drop_equipped_onto_empty_inventory_slot_unequips() -> void:
  _reset_equipment_slots()
  _set_single_inventory_item("core1")
  var blessing_slot := _find_equip_slot(ItemBase.ItemType.BLESSING)
  var blessing := ItemPanelData.new()
  blessing.inst = ItemInstanceStubScript.dummy_item("bless1", ItemBase.ItemType.BLESSING)
  blessing_slot.data = blessing
  blessing_slot._refresh()
  await get_tree().process_frame

  var empty_slot := grid.get_child(1) as ItemSlotPanel
  assert_bool(empty_slot.data == null).is_true()

  EquipSignals.emit_signal("swap_request", blessing_slot, empty_slot)
  await get_tree().process_frame

  assert_bool(blessing_slot.data == null).is_true()
  assert_int(grid.get_items().size()).is_equal(2)


func test_has_equipped_attack_core_false_when_all_empty() -> void:
  _reset_equipment_slots()
  assert_bool(equipment_screen._has_equipped_attack_core()).is_false()


func test_has_equipped_attack_core_true_when_equipped() -> void:
  _reset_equipment_slots()
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if slot is EquipSlotPanel and slot.allowed_type == ItemBase.ItemType.ATTACK_CORE:
      var d := ItemPanelData.new()
      d.inst = ItemInstanceStubScript.dummy_item("core1", ItemBase.ItemType.ATTACK_CORE)
      slot.data = d
      slot._refresh()
      break
  assert_bool(equipment_screen._has_equipped_attack_core()).is_true()


## Helpers -------------------------------------------------------------
func _reset_equipment_slots() -> void:
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if slot is EquipSlotPanel:
      slot.data = null
      slot._refresh()


func _find_equip_slot(item_type: int) -> EquipSlotPanel:
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if slot is EquipSlotPanel and slot.allowed_type == item_type:
      return slot
  return null


func _set_single_inventory_item(uid: String) -> void:
  var d := ItemPanelData.new()
  d.inst = ItemInstanceStubScript.dummy_item(uid, ItemBase.ItemType.ATTACK_CORE)
  var list: Array[ItemPanelData] = [d]
  grid.set_items(list)


func _right_click_event() -> InputEventMouseButton:
  var evt := InputEventMouseButton.new()
  evt.button_index = MOUSE_BUTTON_RIGHT
  evt.pressed = true
  return evt
