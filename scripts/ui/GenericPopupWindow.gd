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


func _on_ok_pressed():
  emit_signal("ok_pressed")


func _on_cancel_pressed():
  emit_signal("cancel_pressed")
