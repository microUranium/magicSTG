extends Control
class_name EquipmentScreen

@onready var grid := $InventoryPanel/ItemListPane/InventoryGrid
@onready var tooltip := $ItemTooltipPanel
@onready var save_btn := $BackButton

@export var generic_popup_window := preload("res://scenes/ui/generic_pop-up_window.tscn")


func _ready():
  GameFlow.play_menu_bgm()

  # Signal 接続
  EquipSignals.swap_request.connect(_on_swap_request)
  EquipSignals.return_item_to_inventory.connect(_on_return_item_to_inventory)
  EquipSignals.swap_to_each_grid.connect(_on_equip_from_inventory)
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


func _set_equipment(data: ItemPanelData) -> bool:
  var equipment_slots := get_tree().get_nodes_in_group("equipment_slots")
  for slot in equipment_slots:
    if slot is EquipSlotPanel and slot.allowed_type == data.inst.prototype.item_type:
      if slot.data:  # 既に何か装備されている場合はスキップ
        continue
      slot.data = data
      slot._refresh()
      slot.equip_changed.emit(data.inst)
      return true  # 一つのスロットにのみ装備可能
  return false  # 空きスロットが無い場合


## ------------------------------------------------------------------
## 入れ替えロジック
## ------------------------------------------------------------------
# ItemSlotPanel / EquipSlotPanel は Drag&Drop 完了時に
#   EquipSignals.emit_signal("swap_request", src, dst)
# を emit する。ここでルール判定→実際のデータ入替を行う。
func _on_swap_request(src: Node, dst: Node):
  var displaced: Dictionary = _swap_items(src, dst)
  var items: Array[ItemPanelData] = _collect_inventory_items()  # 再配置
  if not displaced.is_empty():
    var idx: int = clampi(int(displaced["index"]), 0, items.size())
    items.insert(idx, displaced["data"])
  grid.set_items(items)
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


func _on_equip_from_inventory(src: Node, _grid: Node) -> void:
  # 持ち物欄のアイテムを右クリック → 同タイプの空きスロットへ自動装備
  if not (src is ItemSlotPanel) or src.data == null:
    return
  if _set_equipment(src.data):  # 空きスロットがあれば装備
    src.data = null  # 持ち物欄から除去
    src._refresh()
    grid.set_items(_collect_inventory_items())  # 詰め直し
    grid.emit_signal("ui_needs_refresh")
  # 空きスロットが無い場合は何もしない（アイテムは持ち物欄に残る）


## src のアイテムを dst へ移動／入替する。
## 戻り値: 持ち物一覧へ挿入し直す必要があるアイテム
##   {"data": ItemPanelData, "index": int} … 挿入が必要
##   {}                                    … 挿入不要（スロットへ直接書き込み済み）
func _swap_items(src: Node, dst: Node) -> Dictionary:
  # 同一ノード → 何もしない
  if src == dst:
    return {}

  # 取得元データ
  var src_data: ItemPanelData = src.data
  var dst_data: ItemPanelData = dst.data

  if src_data == null:
    return {}

  # 受入可否
  if !_can_accept(dst, src_data):
    return {}  # ルール外 → キャンセル
  if src is EquipSlotPanel and dst is EquipSlotPanel and src.allowed_type != dst.allowed_type:
    return {}  # 異なる装備種間は不可

  # dst のアイテムを src へ戻せるか（= 単純入替が成立するか）
  var can_swap_back: bool = _can_accept(src, dst_data)

  # 単純入替でない場合は持ち物欄の総数が 1 増えるため、空き容量が必要
  if (
    src is EquipSlotPanel
    and dst is ItemSlotPanel
    and not can_swap_back
    and _collect_inventory_items().size() >= InventoryService.get_max_size()
  ):
    return {}

  var displaced: Dictionary = {}

  if can_swap_back:
    # 単純入替
    src.data = dst_data
    dst.data = src_data
  elif dst is ItemSlotPanel and dst_data != null:
    # 異種のため入替不可。dst のアイテムを上書きせず、src のアイテムを持ち物欄へ挿入する
    src.data = null
    displaced = {
      "data": src_data,
      "index": grid.current_page() * ItemGrid.SLOTS_PER_PAGE + dst.slot_index,
    }
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

  return displaced


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
  if not _has_equipped_attack_core():
    _show_warning_popup("1つ以上の魔法を装備してください。")
    return  # 魔法未装備なら終了せず警告のみ

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


## 魔法(ATTACK_CORE)が1つでも装備されているか
func _has_equipped_attack_core() -> bool:
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if slot is EquipSlotPanel and slot.allowed_type == ItemBase.ItemType.ATTACK_CORE and slot.data:
      return true
  return false


## OKのみの警告ポップアップを表示する
func _show_warning_popup(message: String) -> void:
  var popup: GenericPopupWindow = generic_popup_window.instantiate()
  # EquipmentScreen のルートはサイズ0のため、画面全体サイズのビューポートへ追加する
  get_tree().root.add_child(popup)
  popup.set_message(message)
  popup.set_ok_only()
  popup.ok_pressed.connect(func(): popup.queue_free())  # OKで閉じるだけ
