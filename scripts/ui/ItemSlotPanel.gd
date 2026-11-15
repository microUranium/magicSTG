extends Control
class_name ItemSlotPanel

## Signals -------------------------------------------------------------
signal slot_changed(new_item: ItemInstance)

## Exports -------------------------------------------------------------
@export var slot_index: int = 0  # ページ内 0‑19 の位置
@export var data: ItemPanelData  # null = 空枠

## Constants -----------------------------------------------------------
const EMPTY_ICON: Texture2D = preload("res://assets/gfx/sprites/item_panel_base.png")
const ITEM_FRAME: Texture2D = preload("res://assets/gfx/sprites/item_frame.png")
const BROKEN_ICONS := {
  ItemBase.ItemType.ATTACK_CORE: preload("res://assets/gfx/sprites/magic_broken_sprite.png"),
  ItemBase.ItemType.BLESSING: preload("res://assets/gfx/sprites/blessing_broken_sprite.png"),
}
const BROKEN_FRAME_COLOR := Color("#808080")  # 破壊済みアイテムの枠色（グレー）
const BROKEN_MODULATE := Color(0.5, 0.5, 0.5)  # 破壊済みスロットのグレーアウト

## Ready ---------------------------------------------------------------
@onready var icon: TextureRect = $TextureRect
@onready var frame: TextureRect = $FrameRect


func _ready():
  _refresh()
  icon.connect("mouse_entered", _on_hover)
  icon.connect("mouse_exited", _on_hover_exit)


## Public API ----------------------------------------------------------
func is_broken() -> bool:
  return data != null and data.inst.is_broken


## Private helpers -----------------------------------------------------
func _refresh():
  if data == null:
    icon.texture = EMPTY_ICON
    frame.texture = null
  elif data.inst.is_broken:
    icon.texture = BROKEN_ICONS.get(data.inst.prototype.item_type, data.inst.prototype.icon)
    frame.texture = ITEM_FRAME
    frame.modulate = BROKEN_FRAME_COLOR
  else:
    icon.texture = data.inst.prototype.icon
    frame.texture = ITEM_FRAME
    frame.modulate = data.inst.get_rarity_color()
  modulate = BROKEN_MODULATE if is_broken() else Color.WHITE
  queue_redraw()


## Drag & Drop -------------------------------------------------------
# Drag 開始
func _get_drag_data(_pos):
  if data == null or is_broken():
    return null
  var preview_container := Control.new()
  var preview_icon := TextureRect.new()
  var preview_frame := TextureRect.new()

  preview_icon.texture = icon.texture
  preview_frame.texture = ITEM_FRAME
  preview_frame.modulate = data.inst.get_rarity_color()

  preview_container.add_child(preview_icon)
  preview_container.add_child(preview_frame)

  set_drag_preview(preview_container)
  EquipSignals.drag_started.emit({"inst": data.inst, "src": self})
  return {"type": "item", "inst": data.inst, "src": self}


# ドロップ処理
func _drop_data(_pos, drop):
  EquipSignals.drag_ended.emit()
  if drop.src == self:
    return  # 自分→自分 は無視

  # 交換リクエストを発行
  EquipSignals.emit_signal("swap_request", drop.src, self)


# ドロップ受入可否
func _can_drop_data(_pos, drop):
  # 破壊済みスロットとの交換を許すと、破壊アイテムが相手側（インベントリ）へ移ってしまう
  if is_broken():
    return false
  return drop.has("type") and drop.type == "item"


func _on_hover():
  if data and not is_broken():
    EquipSignals.request_show_item.emit(data.inst)  # アイテム情報を表示


func _on_hover_exit():
  EquipSignals.request_show_item.emit(null)  # アイテム情報を非表示


func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
    if data == null or is_broken():
      return
    EquipSignals.swap_to_each_grid.emit(self, get_parent())  # 別のインベントリへのアイテム移動要求
