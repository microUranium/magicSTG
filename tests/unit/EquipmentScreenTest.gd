class_name EquipmentScreenTest
extends GdUnitTestSuite

const ItemInstanceStubScript := preload("res://tests/stubs/ItemInstanceStub.gd")

var screen: Control
var grid
var grid_trash
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
  grid_trash = screen.get_node("TrashPanel/ItemListPane/InventoryGrid")
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


## 同種加護チェック -----------------------------------------------------
func test_find_duplicate_blessing_returns_null_when_no_blessing() -> void:
  _reset_equipment_slots()
  assert_object(equipment_screen._find_duplicate_blessing()).is_null()


func test_find_duplicate_blessing_detects_same_prototype() -> void:
  _reset_equipment_slots()
  _equip_blessings(["bless_a", "bless_a"])

  assert_object(equipment_screen._find_duplicate_blessing()).is_not_null()


func test_find_duplicate_blessing_allows_distinct_prototypes() -> void:
  _reset_equipment_slots()
  _equip_blessings(["bless_a", "bless_b", "bless_c"])

  assert_object(equipment_screen._find_duplicate_blessing()).is_null()


func test_exit_blocked_by_duplicate_blessing() -> void:
  _reset_equipment_slots()
  _clear_trash()
  _equip_single_attack_core("core1")
  _equip_blessings(["bless_a", "bless_a"])
  await get_tree().process_frame

  equipment_screen._on_save_pressed()
  await get_tree().process_frame

  var popup := _find_popup()
  assert_object(popup).is_not_null()
  assert_str(popup.label.text).is_equal("同じ種類の加護は2つ以上装備できません。")
  _free_popups()


## 退出時のポップアップ連鎖 ---------------------------------------------
func test_exit_blocked_when_no_attack_core_and_trash_empty() -> void:
  # 削除スロットが空なら確認ダイアログを飛ばして魔法チェックへ進むこと
  _reset_equipment_slots()
  _clear_trash()
  await get_tree().process_frame

  equipment_screen._on_save_pressed()
  await get_tree().process_frame

  var popup := _find_popup()
  assert_object(popup).is_not_null()
  assert_str(popup.label.text).is_equal("1つ以上の魔法を装備してください。")
  _free_popups()


func test_exit_shows_confirm_popup_when_trash_has_items() -> void:
  _reset_equipment_slots()
  _equip_single_attack_core("core1")
  _set_trash_items(["trash1"])
  await get_tree().process_frame

  equipment_screen._on_save_pressed()
  await get_tree().process_frame

  var popup := _find_popup()
  assert_object(popup).is_not_null()
  assert_str(popup.label.text).is_equal("削除スロットにあるアイテムは破棄されます")
  assert_bool(popup.cancel_btn.visible).is_true()  # OK / キャンセルの2択
  _free_popups()
  _clear_trash()


func test_commit_inventory_discards_trash_items() -> void:
  var saved: Array[ItemInstance] = InventoryService.get_items()
  _reset_equipment_slots()
  _set_single_inventory_item("core1")
  _set_trash_items(["trash1", "trash2"])
  await get_tree().process_frame

  equipment_screen._commit_inventory()

  var uids: Array[String] = []
  for inst in InventoryService.get_items():
    uids.append(inst.uid)
  assert_array(uids).contains(["core1"])
  assert_array(uids).not_contains(["trash1", "trash2"])

  # 後片付け（InventoryService はオートロードのため復元しておく）
  InventoryService.clear()
  for inst in saved:
    InventoryService.try_add(inst)
  _clear_trash()


## 削除タブ -------------------------------------------------------------
func test_left_tab_toggles_pane_visibility() -> void:
  equipment_screen.set_left_tab(EquipmentScreen.LeftTab.EQUIP)
  assert_bool(equipment_screen.equip_pane.visible).is_true()
  assert_bool(equipment_screen.trash_panel.visible).is_false()

  equipment_screen.set_left_tab(EquipmentScreen.LeftTab.TRASH)
  assert_bool(equipment_screen.equip_pane.visible).is_false()
  assert_bool(equipment_screen.trash_panel.visible).is_true()

  equipment_screen.set_left_tab(EquipmentScreen.LeftTab.EQUIP)


func test_right_click_moves_inventory_item_to_trash_when_trash_tab() -> void:
  _reset_equipment_slots()
  _clear_trash()
  _set_single_inventory_item("core1")
  equipment_screen.set_left_tab(EquipmentScreen.LeftTab.TRASH)
  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel
  inv_slot._gui_input(_right_click_event())
  await get_tree().process_frame

  assert_int(grid.get_items().size()).is_equal(0)
  assert_int(grid_trash.get_items().size()).is_equal(1)
  assert_str(grid_trash.get_items()[0].inst.uid).is_equal("core1")
  # 削除タブでは装備されないこと
  assert_object(_find_equip_slot(ItemBase.ItemType.ATTACK_CORE).data).is_null()

  equipment_screen.set_left_tab(EquipmentScreen.LeftTab.EQUIP)
  _clear_trash()


func test_right_click_returns_trash_item_to_inventory() -> void:
  _reset_equipment_slots()
  _clear_trash()
  var empty: Array[ItemPanelData] = []
  grid.set_items(empty)
  _set_trash_items(["trash1"])
  await get_tree().process_frame

  var trash_slot := grid_trash.get_child(0) as ItemSlotPanel
  assert_object(trash_slot.data).is_not_null()

  trash_slot._gui_input(_right_click_event())
  await get_tree().process_frame

  assert_int(grid_trash.get_items().size()).is_equal(0)
  assert_int(grid.get_items().size()).is_equal(1)
  assert_str(grid.get_items()[0].inst.uid).is_equal("trash1")


func test_drag_inventory_item_into_trash_grid() -> void:
  _reset_equipment_slots()
  _clear_trash()
  _set_single_inventory_item("core1")
  await get_tree().process_frame

  inv_slot = grid.get_child(0) as ItemSlotPanel
  var trash_slot := grid_trash.get_child(0) as ItemSlotPanel

  EquipSignals.emit_signal("swap_request", inv_slot, trash_slot)
  await get_tree().process_frame

  assert_int(grid.get_items().size()).is_equal(0)
  assert_int(grid_trash.get_items().size()).is_equal(1)
  assert_str(grid_trash.get_items()[0].inst.uid).is_equal("core1")
  _clear_trash()


func test_equip_slot_cannot_drop_into_trash() -> void:
  _reset_equipment_slots()
  _clear_trash()
  _equip_single_attack_core("core1")
  await get_tree().process_frame

  var core_slot := _find_equip_slot(ItemBase.ItemType.ATTACK_CORE)
  var trash_slot := grid_trash.get_child(0) as ItemSlotPanel

  EquipSignals.emit_signal("swap_request", core_slot, trash_slot)
  await get_tree().process_frame

  # 装備は外れず、削除スロットにも入らない
  assert_object(core_slot.data).is_not_null()
  assert_str(core_slot.data.inst.uid).is_equal("core1")
  assert_int(grid_trash.get_items().size()).is_equal(0)


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


func _clear_trash() -> void:
  var empty: Array[ItemPanelData] = []
  grid_trash.set_items(empty)


func _set_trash_items(uids: Array) -> void:
  var list: Array[ItemPanelData] = []
  for uid in uids:
    var d := ItemPanelData.new()
    d.inst = ItemInstanceStubScript.dummy_item(uid, ItemBase.ItemType.ATTACK_CORE)
    list.append(d)
  grid_trash.set_items(list)


func _equip_single_attack_core(uid: String) -> void:
  var slot := _find_equip_slot(ItemBase.ItemType.ATTACK_CORE)
  var d := ItemPanelData.new()
  d.inst = ItemInstanceStubScript.dummy_item(uid, ItemBase.ItemType.ATTACK_CORE)
  slot.data = d
  slot._refresh()


## 加護スロットを先頭から proto_ids の順で埋める
func _equip_blessings(proto_ids: Array) -> void:
  var slots: Array[EquipSlotPanel] = []
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if slot is EquipSlotPanel and slot.allowed_type == ItemBase.ItemType.BLESSING:
      slots.append(slot)

  for i in range(min(proto_ids.size(), slots.size())):
    var d := ItemPanelData.new()
    d.inst = ItemInstanceStubScript.dummy_item_with_proto(
      "b%d" % i, proto_ids[i], ItemBase.ItemType.BLESSING
    )
    slots[i].data = d
    slots[i]._refresh()


func _find_popup() -> GenericPopupWindow:
  for child in get_tree().root.get_children():
    if child is GenericPopupWindow and not child.is_queued_for_deletion():
      return child
  return null


func _free_popups() -> void:
  for child in get_tree().root.get_children():
    if child is GenericPopupWindow:
      child.free()
