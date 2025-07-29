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
