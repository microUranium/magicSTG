extends PanelContainer
class_name EquipSlotPanel

## Signals -------------------------------------------------------------
signal equip_changed(new_item: ItemInstance)

## Exports -------------------------------------------------------------
@export_enum("BLESSING", "ATTACK_CORE") var allowed_type := 0
@export var data: ItemPanelData  # null=未装備

const EMPTY_ICON := preload("res://assets/gfx/sprites/item_panel_base.png")
@onready var icon := $TextureRect


func _ready():
  _refresh()
  add_to_group("equipment_slots")
  icon.connect("mouse_entered", _on_hover)
  icon.connect("mouse_exited", _on_hover_exit)
  EquipSignals.drag_started.connect(_on_drag_started)
  EquipSignals.drag_ended.connect(_on_drag_ended)


func _refresh():
  icon.texture = null if data == null else data.inst.prototype.icon
  queue_redraw()


## ハイライト制御 ------------------------------------------------------
func _on_drag_started(payload):
  var accept: bool = payload.inst.prototype.item_type == allowed_type
  self.add_theme_stylebox_override("panel", _highlight_box(accept))


func _on_drag_ended():
  var sb := StyleBoxTexture.new()
  sb.texture = EMPTY_ICON
  sb.modulate_color = Color.WHITE
  self.add_theme_stylebox_override("panel", sb)  # reset


func _highlight_box(accept: bool) -> StyleBoxTexture:
  var sb := StyleBoxTexture.new()
  sb.texture = EMPTY_ICON
  sb.modulate_color = Color.WHITE if accept else Color.DARK_GRAY
  return sb


## Drag & Drop -------------------------------------------------------
func _get_drag_data(_pos):
  if data == null:
    return null
  var p := TextureRect.new()
  p.texture = icon.texture
  set_drag_preview(p)
  EquipSignals.drag_started.emit({"inst": data.inst, "src": self})
  return {"type": "item", "inst": data.inst, "src": self}


func _can_drop_data(_pos, drop):
  return drop.type == "item" and drop.inst.prototype.item_type == allowed_type


func _drop_data(_pos, drop):
  if drop.src == self:
    return
  # 交換ロジックは EquipmentScreen が仲裁
  EquipSignals.emit_signal("swap_request", drop.src, self)
  EquipSignals.emit_signal("equip_slot_drop", self, drop)
  EquipSignals.drag_ended.emit()


# 右クリックで「外す」 ----------------------------------------------
func _gui_input(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
    if data == null:
      return

    EquipSignals.return_item_to_inventory.emit(self)


func _on_hover():
  if data:
    EquipSignals.request_show_item.emit(data.inst)  # アイテム情報を表示


func _on_hover_exit():
  EquipSignals.request_show_item.emit(null)  # アイテム情報を非表示
