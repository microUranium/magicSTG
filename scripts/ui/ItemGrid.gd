extends GridContainer
class_name ItemGrid

## Constants -----------------------------------------------------------
const SLOTS_PER_PAGE := 30

## Nodes ---------------------------------------------------------------
@export var page_label: Label

## Enums ---------------------------------------------------------------
## ソートモード（InventoryPanel のソートボタンはこの順で切り替わる）
enum SortMode { ATTACK_CORE_FIRST, RARITY, BLESSING_FIRST }

## Signals -------------------------------------------------------------
signal sort_requested(mode: SortMode)  # ソートリクエスト

## State ---------------------------------------------------------------
var _page: int = 0
var _pages: PackedInt32Array  # 各ページ先頭インデックス保持
var _items: Array[ItemPanelData] = []  # 所持アイテムデータ (未装備)


func _ready() -> void:
  sort_requested.connect(_on_sort_requested)


## Public API ----------------------------------------------------------
func set_items(items: Array[ItemPanelData]):
  _items = items
  _recalc_pages()
  _populate()


func get_items() -> Array[ItemPanelData]:
  return _items


func get_items_by_page(page_index: int) -> Array[ItemPanelData]:
  var start: int = _pages[page_index]
  var end: int = min(start + SLOTS_PER_PAGE, _items.size())
  return _items.slice(start, end)


func current_page() -> int:
  return _page


func max_page() -> int:
  return _pages.size()


## Signals -------------------------------------------------------------
signal ui_needs_refresh


## Pagination ----------------------------------------------------------
func _recalc_pages():
  var total: int = max(_items.size(), 1)
  var page_cnt := int(ceil(total / float(SLOTS_PER_PAGE)))
  _pages.resize(page_cnt)
  for i in page_cnt:
    _pages[i] = i * SLOTS_PER_PAGE
  _page = clamp(_page, 0, page_cnt - 1)
  EquipSignals.page_changed.emit(_page)


func next_page():
  if _page < max_page() - 1:
    _page += 1
    _populate()


func prev_page():
  if _page > 0:
    _page -= 1
    _populate()


## Populate ------------------------------------------------------------
func _populate():
  for child in get_children():
    if child is ItemSlotPanel:
      child.queue_free()  # 既存のスロットを削除

  # ページ範囲アイテムを取得
  var slice := get_items_by_page(_page)
  # 必要枠数計算
  var need := SLOTS_PER_PAGE
  for idx in need:
    var slot := preload("res://scenes/ui/item_panel.tscn").instantiate()
    slot.slot_index = idx
    if idx < slice.size():
      slot.data = slice[idx]
    add_child(slot)

  # ページラベル更新
  page_label.text = "%d / %d" % [_page + 1, max_page()]

  emit_signal("ui_needs_refresh")


## Private helpers -----------------------------------------------------
func _on_sort_requested(mode: SortMode):
  match mode:
    SortMode.BLESSING_FIRST:
      _items.sort_custom(_type_first_less.bind(ItemBase.ItemType.BLESSING))
    SortMode.ATTACK_CORE_FIRST:
      _items.sort_custom(_type_first_less.bind(ItemBase.ItemType.ATTACK_CORE))
    SortMode.RARITY:
      _items.sort_custom(_rarity_less)
  _recalc_pages()
  _populate()
  emit_signal("ui_needs_refresh")


## 指定タイプを先頭にし、同タイプ内は prototype.id → uid の昇順
## sort_custom は安定ソートではないため、比較関数1つで全順序を決める
func _type_first_less(a: ItemPanelData, b: ItemPanelData, first_type: int) -> bool:
  var a_first: bool = a.inst.prototype.item_type == first_type
  var b_first: bool = b.inst.prototype.item_type == first_type
  if a_first != b_first:
    return a_first
  return _id_uid_less(a, b)


## エンチャントレベル総量の降順、同値なら prototype.id → uid の昇順
func _rarity_less(a: ItemPanelData, b: ItemPanelData) -> bool:
  var a_level: int = a.inst.get_rarity_level()
  var b_level: int = b.inst.get_rarity_level()
  if a_level != b_level:
    return a_level > b_level
  return _id_uid_less(a, b)


## StringName の < は辞書順にならないため String に変換して比較する
func _id_uid_less(a: ItemPanelData, b: ItemPanelData) -> bool:
  var a_id := String(a.inst.prototype.id)
  var b_id := String(b.inst.prototype.id)
  if a_id != b_id:
    return a_id < b_id
  return a.inst.uid < b.inst.uid
