extends Control
class_name ResultInventory

@onready var grid_inv := $InventoryPanel/ItemListPane/InventoryGrid
@onready var grid_results := $ResultInventoryPanel/ItemListPane/InventoryGrid
@onready var result_panel := $ResultInventoryPanel
@onready var tooltip := $ItemTooltipPanel
@onready var back_btn := $BackButton
@onready var bring_all_items_btn := $BringAllItemsFromResultInventory
@onready var debug_label := $Debug

@export var generic_popup_window := preload("res://scenes/ui/generic_pop-up_window.tscn")


#---------------------------------------------------------------------
# Life-cycle
#---------------------------------------------------------------------
func _ready():
  # Signal 接続
  EquipSignals.swap_request.connect(_on_swap_request)
  EquipSignals.swap_to_each_grid.connect(_on_swap_to_each_grid)
  EquipSignals.request_show_item.connect(_on_request_show_item)
  back_btn.connect("pressed", _on_back_pressed)
  bring_all_items_btn.connect("pressed", _on_bring_all_items_from_result_inventory_pressed)
  await get_tree().process_frame
  result_panel.change_label_text("取得アイテム")
  _show_result_items()  # 結果アイテムを表示
  _load_inventory()  # 初期化時にインベントリを読み込む


#---------------------------------------------------------------------
# private helpers
#---------------------------------------------------------------------
func _load_inventory():
  var list: Array[ItemPanelData] = []
  for inst in InventoryService.get_items():
    var d := ItemPanelData.new()
    d.inst = inst
    list.append(d)

  print_debug("Loaded inventory items: %d" % list.size())
  grid_inv.set_items(list)
  grid_inv.sort_requested.emit(ItemBase.ItemType.ATTACK_CORE)  # 初期ソート


func _show_result_items():
  var list: Array[ItemPanelData] = []
  for inst in Ephemeralnventory.get_items():
    var d := ItemPanelData.new()
    d.inst = inst
    list.append(d)

  grid_results.set_items(list)
  grid_results.sort_requested.emit(ItemBase.ItemType.ATTACK_CORE)  # 初期ソート


func _on_swap_request(src: Node, dst: Node):
  _swap_items(src, dst)
  grid_inv.set_items(_collect_inventory_items(grid_inv))
  grid_results.set_items(_collect_inventory_items(grid_results))
  grid_inv.emit_signal("ui_needs_refresh")
  grid_results.emit_signal("ui_needs_refresh")


func _swap_items(src: Node, dst: Node) -> void:
  # 同一ノード → 何もしない
  if src == dst:
    return

  # 取得元データ
  var src_data: ItemPanelData = src.data
  var dst_data: ItemPanelData = dst.data
  var src_grid: ItemGrid = src.get_parent() if src is ItemSlotPanel else null
  var dst_grid: ItemGrid = dst.get_parent() if dst is ItemSlotPanel else null

  if not src_data:
    return
  if not src_grid or not dst_grid:
    return

  # グリッド間の移動の場合、それぞれのアイテム所持情報を更新
  if src_grid != dst_grid:
    if src_grid == grid_inv:
      InventoryService.remove(src_data.inst)
      Ephemeralnventory.add(src_data.inst)
      if dst.data:
        InventoryService.try_add(dst_data.inst)
        Ephemeralnventory.remove(dst_data.inst)
    elif src_grid == grid_results:
      if not dst.data and InventoryService.get_items().size() >= InventoryService.get_max_size():
        print_debug("Inventory is full; cannot add item.")
        return  # インベントリが満杯
      if dst.data:
        InventoryService.remove(dst_data.inst)
        Ephemeralnventory.add(dst_data.inst)
      Ephemeralnventory.remove(src_data.inst)
      InventoryService.try_add(src_data.inst)

  # swap or move
  if dst.data:
    src.data = dst_data
    dst.data = src_data
  else:
    src.data = null
    dst.data = src_data

  # 見た目更新
  if src.has_method("_refresh"):
    src._refresh()
  if dst.has_method("_refresh"):
    dst._refresh()


func _collect_inventory_items(grid: ItemGrid) -> Array[ItemPanelData]:
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


func _on_swap_to_each_grid(src: Node, grid: Node):
  var dst_grid: ItemGrid
  if grid is ItemGrid:
    if grid == grid_inv:
      dst_grid = grid_results
    elif grid == grid_results:
      dst_grid = grid_inv
    else:
      return  # 不明なグリッド

  if src is ItemSlotPanel and src.data:
    var item: ItemPanelData = src.data
    var items: Array[ItemPanelData] = _collect_inventory_items(dst_grid)
    if dst_grid == grid_inv:
      if InventoryService.get_items().size() >= InventoryService.get_max_size():
        print_debug("Inventory is full; cannot add item.")
        return  # インベントリが満杯
      InventoryService.try_add(item.inst)
      Ephemeralnventory.remove(item.inst)
    elif dst_grid == grid_results:
      InventoryService.remove(item.inst)
      Ephemeralnventory.add(item.inst)
    items.append(item)
    src.data = null
    src._refresh()
    dst_grid.set_items(items)
    grid.set_items(_collect_inventory_items(grid))


func _on_request_show_item(item: ItemInstance):
  if item:
    tooltip.show_item(item)
  else:
    tooltip.hide()


func _on_back_pressed():
  if grid_results.get_items().size() > 0:
    _show_popup_dialogue("取得アイテム欄にあるアイテムは失われます。", _on_ok_pressed)
  else:
    _on_ok_pressed()


func _on_ok_pressed():
  # OKボタンが押されたときの処理
  Ephemeralnventory.clear()
  # タイトルへ戻る
  GameFlow.change_to_title()


func _on_bring_all_items_from_result_inventory_pressed():
  if grid_inv.get_items().size() >= InventoryService.get_max_size():
    return  # インベントリが満杯ではない場合は何もしない

  var result_items: Array[ItemPanelData] = _collect_inventory_items(grid_results)
  var inv_items: Array[ItemPanelData] = _collect_inventory_items(grid_inv)
  for item in _collect_inventory_items(grid_results):
    if item.inst:
      var inst: ItemInstance = item.inst
      if InventoryService.try_add(inst):
        Ephemeralnventory.remove(inst)
        result_items.erase(item)
        inv_items.append(item)
      else:
        break

  grid_inv.set_items(inv_items)
  grid_results.set_items(result_items)


func _show_popup_dialogue(message: String, on_ok: Callable):
  var dialogue: GenericPopupWindow = generic_popup_window.instantiate()
  get_tree().current_scene.add_child(dialogue)
  dialogue.set_message(message)
  dialogue.ok_pressed.connect(on_ok)
  dialogue.cancel_pressed.connect(func(): dialogue.queue_free())  # ダイアログを閉じる


func _process(delta: float) -> void:
  # デバッグ情報更新
  debug_label.text = (
    "Inventory Size: %d/%d\nResult Size: %d"
    % [
      InventoryService.get_items().size(),
      InventoryService.get_max_size(),
      Ephemeralnventory.get_items().size()
    ]
  )
