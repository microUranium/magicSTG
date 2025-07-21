extends Control
class_name EquipmentScreen

@onready var grid := $InventoryPanel/ItemListPane/InventoryGrid
@onready var btn_prev := $InventoryPanel/ItemListPane/PageControls/prev
@onready var btn_next := $InventoryPanel/ItemListPane/PageControls/next
@onready var tooltip := $ItemTooltipPanel
@onready var sort_btn := $InventoryPanel/ItemListPane/Sort
@onready var save_btn := $BackButton

var _current_sort: int = ItemBase.ItemType.ATTACK_CORE  # 現在のソート状態


func _ready():
  # Signal 接続
  grid.ui_needs_refresh.connect(_update_nav)
  EquipSignals.page_changed.connect(_update_nav)
  EquipSignals.swap_request.connect(_on_swap_request)
  EquipSignals.return_item_to_inventory.connect(_on_return_item_to_inventory)
  EquipSignals.request_show_item.connect(_on_request_show_item)
  # PlayerSaveData.data_loaded.connect(_set_inventory)

  save_btn.connect("pressed", _on_save_pressed)
  sort_btn.connect("pressed", _on_sort_pressed)
  btn_prev.connect("pressed", _on_prev_pressed)
  btn_next.connect("pressed", _on_next_pressed)
  await get_tree().process_frame
  _load_inventory()  # 初期化時にインベントリを読み込む


func _load_inventory():
  var equipped_attack_core_uid: Array[String] = []
  var equipped_blessings_uid: Array[String] = []

  for item in PlayerSaveData.get_attack_cores():
    equipped_attack_core_uid.append(item.uid)

  for item in PlayerSaveData.get_blessings():
    equipped_blessings_uid.append(item.uid)

  var list: Array[ItemPanelData] = []
  for inst in InventoryService.get_items():
    var d := ItemPanelData.new()
    d.inst = inst
    if inst.uid in equipped_attack_core_uid:
      _set_equipment(d)  # 装備スロットへ配置
      continue
    elif inst.uid in equipped_blessings_uid:
      _set_equipment(d)  # 装備スロットへ配置
      continue
    else:
      list.append(d)

  print_debug("Loaded inventory items: %d" % list.size())
  grid.set_items(list)
  # ソート状態を初期化
  _on_sort_pressed()
  _update_nav()


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
  _update_nav()


func _on_return_item_to_inventory(pane: Node):
  print_debug("Returning item to inventory from pane: ", pane.name)
  if pane is EquipSlotPanel and pane.data:
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


func _update_nav():
  btn_prev.visible = grid.max_page() > 1
  btn_next.visible = grid.max_page() > 1
  btn_prev.disabled = grid.current_page() == 0
  btn_next.disabled = grid.current_page() == grid.max_page() - 1


# ページング
func _on_prev_pressed():
  grid.prev_page()


func _on_next_pressed():
  grid.next_page()


# ソート
func _on_sort_pressed():
  _current_sort = (_current_sort + 1) % ItemBase.ItemType.size()
  EquipSignals.sort_requested.emit(_current_sort)
  # ソートボタンの表示更新
  var type_names := ["加護", "魔法"]
  sort_btn.text = "ソート: %s" % type_names[_current_sort]


# 保存
func _on_save_pressed():
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
