extends Control
class_name EquipmentScreen

## 左ペインのタブ
enum LeftTab { EQUIP, TRASH }

## 退出時の検証ステップ。順序を変えたい場合はこの並びを入れ替える。
enum ExitStep { CONFIRM_TRASH, CHECK_ATTACK_CORE, CHECK_DUPLICATE_BLESSING, COMMIT }

@onready var grid_inv: ItemGrid = $InventoryPanel/ItemListPane/InventoryGrid
@onready var grid_trash: ItemGrid = $TrashPanel/ItemListPane/InventoryGrid
@onready var trash_panel: InventoryPanel = $TrashPanel
@onready var equip_pane: Control = $EquipPane
@onready var tab_equip: Button = $LeftPaneTabs/TabEquip
@onready var tab_trash: Button = $LeftPaneTabs/TabTrash
@onready var tooltip := $ItemTooltipPanel
@onready var save_btn := $BackButton

@export var generic_popup_window := preload("res://scenes/ui/generic_pop-up_window.tscn")

var _left_tab: int = LeftTab.EQUIP


func _ready():
  GameFlow.play_menu_bgm()

  # Signal 接続
  EquipSignals.swap_request.connect(_on_swap_request)
  EquipSignals.return_item_to_inventory.connect(_on_return_item_to_inventory)
  EquipSignals.swap_to_each_grid.connect(_on_swap_to_each_grid)
  EquipSignals.request_show_item.connect(_on_request_show_item)
  # PlayerSaveData.data_loaded.connect(_set_inventory)

  save_btn.connect("pressed", _on_save_pressed)
  tab_equip.connect("pressed", _on_tab_equip_pressed)
  tab_trash.connect("pressed", _on_tab_trash_pressed)

  trash_panel.change_label_text("削除")
  _apply_left_tab()

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
  grid_inv.set_items(list)
  grid_inv.sort_requested.emit(ItemBase.ItemType.ATTACK_CORE)  # 初期ソート

  # 削除スロットは常に空の状態で開始する
  var empty: Array[ItemPanelData] = []
  grid_trash.set_items(empty)


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
## タブ切替
## ------------------------------------------------------------------
func _on_tab_equip_pressed() -> void:
  set_left_tab(LeftTab.EQUIP)


func _on_tab_trash_pressed() -> void:
  set_left_tab(LeftTab.TRASH)


func set_left_tab(tab: int) -> void:
  _left_tab = tab
  _apply_left_tab()


func get_left_tab() -> int:
  return _left_tab


## 表示切替は必ず visible で行うこと。
## 非表示の Control はドロップを受け付けないため、
## これが「装備スロット ⇄ 削除スロット」の直接ドラッグを構造的に防いでいる。
func _apply_left_tab() -> void:
  equip_pane.visible = _left_tab == LeftTab.EQUIP
  trash_panel.visible = _left_tab == LeftTab.TRASH
  tab_equip.button_pressed = _left_tab == LeftTab.EQUIP
  tab_trash.button_pressed = _left_tab == LeftTab.TRASH


## ------------------------------------------------------------------
## 入れ替えロジック
## ------------------------------------------------------------------
# ItemSlotPanel / EquipSlotPanel は Drag&Drop 完了時に
#   EquipSignals.emit_signal("swap_request", src, dst)
# を emit する。ここでルール判定→実際のデータ入替を行う。
func _on_swap_request(src: Node, dst: Node):
  var displaced: Dictionary = _swap_items(src, dst)

  # src / dst が属するグリッドだけを再構築する（装備スロット同士なら何もしない）
  var touched: Array[ItemGrid] = []
  for g in [_grid_of(src), _grid_of(dst)]:
    if g != null and not touched.has(g):
      touched.append(g)

  for g in touched:
    var items: Array[ItemPanelData] = _collect_items(g)  # 再配置
    if not displaced.is_empty() and displaced["grid"] == g:
      var idx: int = clampi(int(displaced["index"]), 0, items.size())
      items.insert(idx, displaced["data"])
    g.set_items(items)
    g.emit_signal("ui_needs_refresh")


func _on_return_item_to_inventory(pane: Node):
  if (
    pane is EquipSlotPanel
    and pane.data
    and _collect_items(grid_inv).size() < InventoryService.get_max_size()
  ):
    # 装備スロットからインベントリへ戻す
    var item: ItemPanelData = pane.data
    var items: Array[ItemPanelData] = grid_inv.get_items()
    items.append(item)  # インベントリに追加
    grid_inv.set_items(items)  # 更新
    pane.data = null  # スロットを空に
    pane._refresh()  # 見た目更新
    pane.equip_changed.emit(null)  # 装備変更通知


## 持ち物欄／削除スロットの右クリック。開いているタブに応じて振り分ける。
func _on_swap_to_each_grid(src: Node, from_grid: Node) -> void:
  if not (src is ItemSlotPanel) or src.data == null:
    return

  if from_grid == grid_trash:
    _move_between_grids(src, grid_trash, grid_inv)  # 削除スロット → 持ち物欄
  elif from_grid == grid_inv:
    if _left_tab == LeftTab.TRASH:
      _move_between_grids(src, grid_inv, grid_trash)  # 持ち物欄 → 削除スロット
    else:
      _equip_from_inventory(src)  # 持ち物欄 → 空き装備スロット


func _equip_from_inventory(src: ItemSlotPanel) -> void:
  # 持ち物欄のアイテムを右クリック → 同タイプの空きスロットへ自動装備
  if _set_equipment(src.data):  # 空きスロットがあれば装備
    src.data = null  # 持ち物欄から除去
    src._refresh()
    grid_inv.set_items(_collect_items(grid_inv))  # 詰め直し
    grid_inv.emit_signal("ui_needs_refresh")
  # 空きスロットが無い場合は何もしない（アイテムは持ち物欄に残る）


## スロット単位でグリッド間を移動させる。
func _move_between_grids(src: ItemSlotPanel, from_grid: ItemGrid, to_grid: ItemGrid) -> void:
  if to_grid == grid_inv and _collect_items(grid_inv).size() >= InventoryService.get_max_size():
    print_debug("Inventory is full; cannot move item.")
    return

  var item: ItemPanelData = src.data
  var dst_items: Array[ItemPanelData] = _collect_items(to_grid)
  dst_items.append(item)

  src.data = null
  src._refresh()

  to_grid.set_items(dst_items)
  from_grid.set_items(_collect_items(from_grid))  # 詰め直し
  to_grid.emit_signal("ui_needs_refresh")
  from_grid.emit_signal("ui_needs_refresh")


## src のアイテムを dst へ移動／入替する。
## 戻り値: グリッドへ挿入し直す必要があるアイテム
##   {"data": ItemPanelData, "grid": ItemGrid, "index": int} … 挿入が必要
##   {}                                                      … 挿入不要（スロットへ直接書き込み済み）
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
  # 装備スロットから削除スロットへの直接移動も不可（一度持ち物欄へ戻させる）
  if !_can_accept(dst, src_data) or (src is EquipSlotPanel and _grid_of(dst) == grid_trash):
    return {}  # ルール外 → キャンセル
  if src is EquipSlotPanel and dst is EquipSlotPanel and src.allowed_type != dst.allowed_type:
    return {}  # 異なる装備種間は不可

  # dst のアイテムを src へ戻せるか（= 単純入替が成立するか）
  var can_swap_back: bool = _can_accept(src, dst_data)
  var dst_grid: ItemGrid = _grid_of(dst)

  # 単純入替でない場合は持ち物欄の総数が 1 増えるため、空き容量が必要
  # （削除スロットには上限を設けない）
  if (
    src is EquipSlotPanel
    and dst_grid == grid_inv
    and not can_swap_back
    and _collect_items(grid_inv).size() >= InventoryService.get_max_size()
  ):
    return {}

  var displaced: Dictionary = {}

  if can_swap_back:
    # 単純入替（グリッドをまたぐ場合もこの経路を通る）
    src.data = dst_data
    dst.data = src_data
  elif dst is ItemSlotPanel and dst_data != null:
    # 異種のため入替不可。dst のアイテムを上書きせず、src のアイテムを dst 側グリッドへ挿入する
    src.data = null
    displaced = {
      "data": src_data,
      "grid": dst_grid,
      "index": dst_grid.current_page() * ItemGrid.SLOTS_PER_PAGE + dst.slot_index,
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


## ItemSlotPanel が属する ItemGrid を返す（装備スロットなど、該当しなければ null）
func _grid_of(node: Node) -> ItemGrid:
  if node is ItemSlotPanel:
    var parent := node.get_parent()
    return parent if parent is ItemGrid else null
  return null


## 指定グリッドの全ページのアイテムを収集する
func _collect_items(g: ItemGrid) -> Array[ItemPanelData]:
  var items: Array[ItemPanelData] = []
  if g == null:
    return items

  for page in range(g.max_page()):
    if page == g.current_page():
      for slot in g.get_children():
        if slot is ItemSlotPanel and slot.data != null:
          items.append(slot.data)
    else:
      for data in g.get_items_by_page(page):
        items.append(data)

  return items


## ------------------------------------------------------------------
## 退出処理
## ------------------------------------------------------------------
func _on_save_pressed():
  _run_exit_step(ExitStep.CONFIRM_TRASH)


## ポップアップが非同期なので、ステップ番号で検証チェーンを駆動する。
func _run_exit_step(step: int) -> void:
  match step:
    ExitStep.CONFIRM_TRASH:
      if _collect_items(grid_trash).is_empty():
        _run_exit_step(ExitStep.CHECK_ATTACK_CORE)
        return
      _show_confirm_popup(
        "削除スロットにあるアイテムは破棄されます", func(): _run_exit_step(ExitStep.CHECK_ATTACK_CORE)
      )

    ExitStep.CHECK_ATTACK_CORE:
      if not _has_equipped_attack_core():
        _show_warning_popup("1つ以上の魔法を装備してください。")
        return  # 魔法未装備なら終了せず警告のみ
      _run_exit_step(ExitStep.CHECK_DUPLICATE_BLESSING)

    ExitStep.CHECK_DUPLICATE_BLESSING:
      if _find_duplicate_blessing() != null:
        _show_warning_popup("同じ種類の加護は2つ以上装備できません。")
        return  # 重複があれば終了せず警告のみ
      _run_exit_step(ExitStep.COMMIT)

    ExitStep.COMMIT:
      _commit_and_exit()


func _commit_and_exit() -> void:
  _apply_changes()
  # タイトルへ戻る
  GameFlow.change_to_title()


## 画面遷移を伴わない確定処理。
func _apply_changes() -> void:
  _commit_inventory()

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

  # 破棄済みのアイテムが残らないよう削除スロットを空にする
  var empty: Array[ItemPanelData] = []
  grid_trash.set_items(empty)


## 持ち物欄の内容だけを InventoryService へ反映する。
## 削除スロットのアイテムは再登録しないため、これが削除処理そのものになる。
func _commit_inventory() -> void:
  var discarded: Array[ItemPanelData] = _collect_items(grid_trash)
  if not discarded.is_empty():
    print_debug("Discarding %d item(s) from trash slots." % discarded.size())

  var inventory_items: Array[ItemPanelData] = _collect_items(grid_inv)
  InventoryService.clear()
  for item in inventory_items:
    if item.inst:
      InventoryService.try_add(item.inst)


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


## 同種の加護が2つ以上装備されていれば、その重複インスタンスを返す（無ければ null）
## 「同種」の判定キーは ItemBase.id（uid はインスタンス固有のため使えない）
func _find_duplicate_blessing() -> ItemInstance:
  var seen := {}
  for slot in get_tree().get_nodes_in_group("equipment_slots"):
    if not (slot is EquipSlotPanel):
      continue
    if slot.allowed_type != ItemBase.ItemType.BLESSING or slot.data == null:
      continue
    var proto_id: StringName = slot.data.inst.prototype.id
    if seen.has(proto_id):
      return slot.data.inst
    seen[proto_id] = true
  return null


## OKのみの警告ポップアップを表示する
func _show_warning_popup(message: String) -> void:
  var popup: GenericPopupWindow = generic_popup_window.instantiate()
  # EquipmentScreen のルートはサイズ0のため、画面全体サイズのビューポートへ追加する
  get_tree().root.add_child(popup)
  popup.set_message(message)
  popup.set_ok_only()
  popup.ok_pressed.connect(func(): popup.queue_free())  # OKで閉じるだけ


## OK / キャンセルの確認ポップアップを表示する
func _show_confirm_popup(message: String, on_ok: Callable) -> void:
  var popup: GenericPopupWindow = generic_popup_window.instantiate()
  get_tree().root.add_child(popup)
  popup.set_message(message)
  popup.ok_pressed.connect(
    func():
      popup.queue_free()
      on_ok.call()
  )
  popup.cancel_pressed.connect(func(): popup.queue_free())
