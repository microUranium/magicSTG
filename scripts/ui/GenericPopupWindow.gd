extends Control
class_name GenericPopupWindow

signal ok_pressed
signal cancel_pressed

@onready var label: RichTextLabel = $Label
@onready var ok_btn: Button = $OK
@onready var cancel_btn: Button = $Cancel


func _ready():
  ok_btn.connect("pressed", _on_ok_pressed)
  cancel_btn.connect("pressed", _on_cancel_pressed)


func set_message(message: String):
  label.text = message


## OKボタンのみ・ウィンドウ下中央に配置するモードへ切り替える
func set_ok_only() -> void:
  cancel_btn.hide()
  # OK ボタンをウィンドウ下中央へ（画面中央=ウィンドウ中央にアンカー）
  var w := ok_btn.offset_right - ok_btn.offset_left  # 既存の幅を維持
  ok_btn.anchor_left = 0.5
  ok_btn.anchor_right = 0.5
  ok_btn.offset_left = -w / 2.0
  ok_btn.offset_right = w / 2.0


func _on_ok_pressed():
  emit_signal("ok_pressed")


func _on_cancel_pressed():
  emit_signal("cancel_pressed")
