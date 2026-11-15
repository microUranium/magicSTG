extends Control
class_name InventoryPanel

@onready var grid := $ItemListPane/InventoryGrid
@onready var btn_prev := $ItemListPane/PageControls/prev
@onready var btn_next := $ItemListPane/PageControls/next
@onready var sort_btn := $ItemListPane/Sort
@onready var panel_label := $Label

const SORT_LABELS := {
  ItemGrid.SortMode.ATTACK_CORE_FIRST: "魔法",
  ItemGrid.SortMode.RARITY: "レア度",
  ItemGrid.SortMode.BLESSING_FIRST: "加護",
}

var _current_sort: ItemGrid.SortMode = ItemGrid.SortMode.ATTACK_CORE_FIRST  # 現在のソート状態


func _ready():
  # Signal 接続
  grid.ui_needs_refresh.connect(_update_nav)
  EquipSignals.page_changed.connect(_update_nav)
  sort_btn.connect("pressed", _on_sort_pressed)
  btn_prev.connect("pressed", _on_prev_pressed)
  btn_next.connect("pressed", _on_next_pressed)


# grid.ui_needs_refresh(引数なし) と EquipSignals.page_changed(page: int) の両方から呼ばれる
func _update_nav(_page: int = 0):
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
  _current_sort = ((_current_sort + 1) % ItemGrid.SortMode.size()) as ItemGrid.SortMode
  grid.sort_requested.emit(_current_sort)
  # ソートボタンの表示更新
  sort_btn.text = "ソート: %s" % SORT_LABELS[_current_sort]


func change_label_text(text: String):
  panel_label.text = text
