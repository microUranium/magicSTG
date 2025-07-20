extends Control
class_name ItemTooltipPanel

const OFFSET := Vector2(16, 16)  # マウスの少し右下に表示
const MARGIN_X := 500  # 画面端からの余白
const MARGIN_Y := 250  # 画面端からの余白


func _ready() -> void:
  hide_tooltip()  # 初期状態では非表示


## Public API ----------------------------------------------------------
func show_item(inst: ItemInstance):
  $VBoxContainer/Label.text = inst.prototype.display_name
  $VBoxContainer/Label2.text = (
    "魔法" if inst.prototype.item_type == ItemBase.ItemType.ATTACK_CORE else "加護"
  )
  $VBoxContainer/RichTextLabel.text = inst.prototype.description
  $VBoxContainer/RichTextLabel2.text = _format_enchant(inst)
  visible = true


func hide_tooltip():
  visible = false


func _format_enchant(inst: ItemInstance) -> String:
  var txt = ""
  for e in inst.enchantments:
    var level = inst.enchantments[e]
    # レベルをローマ数字で表示
    var level_str = (
      "I" if level == 1 else "II" if level == 2 else "III" if level == 3 else str(level)
    )
    txt += "%s %s: %s\n" % [e.display_name, level_str, e.description]
  return txt


func _process(_delta: float) -> void:
  if !visible:
    return
  var vp := get_viewport()
  var pos := vp.get_mouse_position() + OFFSET
  # 画面外にはみ出さないようクランプ
  var rect := Rect2(Vector2.ZERO, vp.get_visible_rect().size)
  rect.position += Vector2(MARGIN_X, MARGIN_Y)
  rect.size -= Vector2(MARGIN_X * 2, MARGIN_Y * 2)
  global_position = pos.clamp(rect.position, rect.position + rect.size)
