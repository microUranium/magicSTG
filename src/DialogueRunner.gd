extends CanvasLayer
class_name DialogueRunner

signal dialogue_finished(dialogue_data: DialogueData)

@export var message_box_scene: PackedScene = preload("res://assets/message_box/message_box.tscn")

var _dialogue_data: DialogueData
var _line_idx: int = 0
var _msgbox: Control
var _side_face := { "left": null, "right": null }

var _ext_cb : Callable = Callable()

# --------------------------------------------------
# Public API : StageManager が呼ぶ
# --------------------------------------------------
func start(dialogue_data: DialogueData) -> void:
  if not dialogue_data or dialogue_data.lines.is_empty():
    push_warning("DialogueRunner: dialogue_data is empty.")
    _finish_dialogue()
    return

  _dialogue_data = dialogue_data
  _line_idx = 0

  _msgbox = message_box_scene.instantiate()
  add_child(_msgbox)
  _msgbox.advance_requested.connect(_on_advance)

  _show_current_line()

func start_with_callback(dialogue_data: DialogueData, finished_cb: Callable) -> void:
  _ext_cb = finished_cb
  # 一度きりで自動解除
  connect("dialogue_finished",
          Callable(self, "_relay_dialogue_finished"),
          CONNECT_ONE_SHOT)
  start(dialogue_data)

# --------------------------------------------------
# Face Cache & Side Assignment
# --------------------------------------------------
func _read_faces(_current_dialog_line: DialogueLine) -> void:
  if _current_dialog_line.face_left:
    _side_face["left"] = _current_dialog_line.face_left
  if _current_dialog_line.face_right:
    _side_face["right"] = _current_dialog_line.face_right

  _msgbox.set_face_textures(_side_face["left"], _side_face["right"])

# --------------------------------------------------
# Internal Methods
# --------------------------------------------------
func _show_current_line() -> void:
  if _line_idx >= _dialogue_data.lines.size():
    _finish_dialogue()
    return
  var line: DialogueLine = _dialogue_data.lines[_line_idx]

  _read_faces(line)
  if not _msgbox.visible:
    await _msgbox.fade_in(line.box_direction)
  _msgbox.show_line(line)

func _on_advance() -> void:
  _line_idx += 1
  _show_current_line()

func _relay_dialogue_finished(_dd: DialogueData) -> void:
  if _ext_cb.is_valid():
    _ext_cb.call()          # 引数なしで安全に呼び出す
    _ext_cb = Callable()    # 解放

  print_debug("DialogueRunner: Dialogue finished.", _ext_cb.get_method())

# --------------------------------------------------
# Finish
# --------------------------------------------------
func _finish_dialogue() -> void:
  if _msgbox:
    await _msgbox.fade_out()
    _msgbox.queue_free()
  emit_signal("dialogue_finished", _dialogue_data)