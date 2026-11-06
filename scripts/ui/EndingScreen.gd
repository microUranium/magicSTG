extends CanvasLayer
class_name EndingScreen
## ラスボス撃破後に表示するエンディング画面。
## 最前面に一枚絵をフェードインし、フェードイン完了後のクリックで finished を emit する。
## 全画面の Background がクリックを止めるため、背面の UI には入力が届かない。

@export_range(0.1, 10.0, 0.1, "suffix:s") var fade_duration: float = 2.0

signal finished  # クリックされたら emit（一度だけ）

@onready var _background: TextureRect = $Background

var _accepting := false  # フェードイン完了後のみクリックを受け付ける
var _finished := false


func _ready() -> void:
  _background.modulate.a = 0.0
  _background.gui_input.connect(_on_background_gui_input)

  var tween := create_tween()
  tween.tween_property(_background, "modulate:a", 1.0, fade_duration)
  tween.finished.connect(_on_fade_in_finished)


func _on_fade_in_finished() -> void:
  _accepting = true


func _on_background_gui_input(event: InputEvent) -> void:
  if not (event is InputEventMouseButton):
    return
  var mb := event as InputEventMouseButton
  if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
    return
  _background.accept_event()
  if not _accepting or _finished:
    return
  _finished = true
  finished.emit()
