extends Control
class_name EquipmentScreen

@onready var grid := $InventoryPanel/ItemListPane/InventoryGrid
@onready var tooltip := $ItemTooltipPanel
@onready var save_btn := $BackButton


func _ready():
  # Signal 接続
  EquipSignals.swap_request.connect(_on_swap_request)
  EquipSignals.return_item_to_inventory.connect(_on_return_item_to_inventory)
  EquipSignals.request_show_item.connect(_on_request_show_item)
  # PlayerSaveData.data_loaded.connect(_set_inventory)

  save_btn.connect("pressed", _on_save_pressed)
  await get_tree().process_frame
  _load_inventory()  # 初期化時にインベントリを読み込む


func _load_inventory():
  for item in PlayerSaveData.get_all_equipped_items():
    var d := ItemPanelData.new()
    d.inst = item
    _set_equipment(d)

  var list: Array[ItemPanelData] = []
  for inst in InventoryService.get_items():
    var d := ItemPanelData.new()
    d.inst = inst
    list.append(d)

  print_debug("Loaded inventory items: %d" % list.size())
  grid.set_items(list)
  grid.sort_requested.emit(ItemBase.ItemType.ATTACK_CORE)  # 初期ソート


func _set_equipment(data: ItemPanelData):
  var equipment_slots := get_tree().get_nodes_in_group("equipment_slots")
  for slot in equipment_slots:
    if slot is EquipSlotPanel and slot.allowed_type == data.inst.prototype.item_type:
      if slot.data:  # 既に何か装備されている場合はスキップ
        continue
      slot.data = data
      slot._refresh()
      slot.equip_changed.emit(data.inst)
      return  # 一つのスロットにのみ装備可能


## ------------------------------------------------------------------
## 入れ替えロジック
## ------------------------------------------------------------------
# ItemSlotPanel / EquipSlotPanel は Drag&Drop 完了時に
#   EquipSignals.emit_signal("swap_request", src, dst)
# を emit する。ここでルール判定→実際のデータ入替を行う。
func _on_swap_request(src: Node, dst: Node):
  _swap_items(src, dst)
  grid.set_items(_collect_inventory_items())  # 再配置
  grid.emit_signal("ui_needs_refresh")


func _on_return_item_to_inventory(pane: Node):
  if (
    pane is EquipSlotPanel
    and pane.data
    and _collect_inventory_items().size() < InventoryService.get_max_size()
  ):
    # 装備スロットからインベントリへ戻す
    var item: ItemPanelData = pane.data
    var items: Array[ItemPanelData] = grid.get_items()
    items.append(item)  # インベントリに追加
    grid.set_items(items)  # 更新
    pane.data = null  # スロットを空に
    pane._refresh()  # 見た目更新
    pane.equip_changed.emit(null)  # 装備変更通知


func _swap_items(src: Node, dst: Node) -> void:
  # 同一ノード → 何もしない
  if src == dst:
    return

  # 取得元データ
  var src_data: ItemPanelData = src.data
  var dst_data: ItemPanelData = dst.data

  # 取得元データの情報とSlopPanelの型をデバッグ出力
  print_debug("Swapping items: src=%s, dst=%s" % [src_data, dst_data])
  print_debug(
    (
      "Source type: %s, Destination type: %s"
      % [
        "Equip" if src is EquipSlotPanel else "Inventory",
        "Equip" if dst is EquipSlotPanel else "Inventory"
      ]
    )
  )

  # 受入可否
  if !_can_accept(dst, src_data):
    return  # ルール外 → キャンセル
  if src is EquipSlotPanel and dst is EquipSlotPanel and src.allowed_type != dst.allowed_type:
    return  # 異なる装備種間は不可
  if (
    src is EquipSlotPanel
    and dst is ItemSlotPanel
    and _collect_inventory_items().size() >= InventoryService.get_max_size()
  ):
    return

  # swap or move
  if _can_accept(src, dst_data):
    # 単純入替
    src.data = dst_data
    dst.data = src_data
  else:
    # dst へ移動のみ、src を空に
    src.data = null
    dst.data = src_data

  # 見た目更新
  if src.has_method("_refresh"):
    src._refresh()
  if dst.has_method("_refresh"):
    dst._refresh()

  # 装備変更通知
  if src is EquipSlotPanel:
    src.equip_changed.emit(src.data.inst if src.data != null else null)
  if dst is EquipSlotPanel:
    dst.equip_changed.emit(dst.data.inst if dst.data != null else null)

  # 判定関数


func _can_accept(panel: Node, data: ItemPanelData) -> bool:
  if panel is ItemSlotPanel:
    return true  # インベントリ枠は何でも保持可
  if panel is EquipSlotPanel:
    return data != null and data.inst.prototype.item_type == panel.allowed_type
  return false


func _collect_inventory_items() -> Array[ItemPanelData]:
  var items: Array[ItemPanelData] = []
  # 全ページのアイテムを収集
  for page in range(grid.max_page()):
    if page == grid.current_page():
      for slot in grid.get_children():
        if slot is ItemSlotPanel and slot.data != null:
          items.append(slot.data)
    else:
      for data in grid.get_items_by_page(page):
        items.append(data)

  return items


# 保存
func _on_save_pressed():
  var inventory_items: Array[ItemPanelData] = _collect_inventory_items()
  InventoryService.clear()
  for item in inventory_items:
    if item.inst:
      InventoryService.try_add(item.inst)

  var new_equipment_attack_core: Array[ItemInstance] = []
  var new_equipment_blessings: Array[ItemInstance] = []

  var equipment_slots := get_tree().get_nodes_in_group("equipment_slots")
  for slot in equipment_slots:
    if slot is EquipSlotPanel:
      if !slot.data:
        continue
      if slot.allowed_type == ItemBase.ItemType.ATTACK_CORE:
        new_equipment_attack_core.append(slot.data.inst)
      elif slot.allowed_type == ItemBase.ItemType.BLESSING:
        new_equipment_blessings.append(slot.data.inst)

  # 保存データを更新
  PlayerSaveData.clear_equipment()
  PlayerSaveData.set_attack_cores(new_equipment_attack_core)
  PlayerSaveData.set_blessings(new_equipment_blessings)

  # TODO: 保存処理

  # タイトルへ戻る
  GameFlow.change_to_title()


func _on_request_show_item(item: ItemInstance):
  if item:
    tooltip.show_item(item)
  else:
    tooltip.hide()
