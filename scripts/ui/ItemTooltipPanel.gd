extends Control
class_name ItemTooltipPanel

const OFFSET := Vector2(16, 16)  # マウスの少し右下に表示
const BG_BOTTOM_PAD := 12  # VBox 下端から背景下端までの余白

@onready var _bg: NinePatchRect = $NinePatchRect
@onready var _vbox: VBoxContainer = $VBoxContainer


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
  visible = true  # 先に表示してレイアウトを走らせる（非表示のままだとラベル幅が確定せず測定がズレる）
  await get_tree().process_frame  # fit_content のレイアウト確定を待つ
  _resize_background()


func hide_tooltip():
  visible = false


## テキスト量に応じて背景 NinePatchRect の高さを伸縮させる
func _resize_background() -> void:
  var content_height := _vbox.get_combined_minimum_size().y
  _bg.size.y = _vbox.position.y + content_height + BG_BOTTOM_PAD


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
  var screen := vp.get_visible_rect().size
  var size := _bg.size  # 実際のツールチップサイズ
  var mouse := vp.get_mouse_position()

  # 既定はカーソル右下。下にはみ出すならカーソルの上へ反転
  var pos := mouse + OFFSET
  if pos.y + size.y > screen.y:
    pos.y = mouse.y - OFFSET.y - size.y  # カーソルの上に出す

  # 最終的に実サイズで画面内へクランプ
  pos.x = clampf(pos.x, 0.0, maxf(0.0, screen.x - size.x))
  pos.y = clampf(pos.y, 0.0, maxf(0.0, screen.y - size.y))
  global_position = pos
