extends Control

signal advance_requested

@export var left_actor_name  := "LEFT"   # DialogueLine.speaker_name と一致させる
@export var right_actor_name := "RIGHT"
@export var highlight_alpha  := 1.0
@export var dim_alpha        := 0.4
@export var char_interval    := 0.05        # 1 文字当たり秒
@export var fade_time := 0.25               # フェード秒数
@export var slide_distance_face   := 300.0
@export var slide_distance_box    := 100.0

@onready var _face_left : TextureRect = $"FaceLeft"
@onready var _face_right: TextureRect = $"FaceRight"
@onready var _label     : RichTextLabel = $"Label"
@onready var _click_area : ColorRect = $"ClickableArea"
@onready var _box : Control = $"Box" # フキダシの親

#-------------------------------------------------
# Typing state
#-------------------------------------------------
var _full_text : String = ""
var _char_idx  : int    = 0
var _timer     : SceneTreeTimer
var _is_typing : bool   = false
var _left_home  : Vector2 # フェードイン時初期位置
var _right_home : Vector2 # フェードイン時初期位置
var _box_home : Vector2 # フキダシの初期位置
var _label_home : Vector2 # ラベルの初期位置

#=================================================
# Life-cycle
#=================================================
func _ready() -> void:
  _click_area.color = Color(0,0,0,0)                     # 完全透明
  _click_area.mouse_filter = Control.MOUSE_FILTER_STOP   # クリックキャッチ
  _click_area.gui_input.connect(_on_click_area_input)

  _left_home  = _face_left.position
  _right_home = _face_right.position
  _box_home = _box.position
  _label_home = _label.position

  visible = false

# --------------------------------------------------
# Public API : DialogueRunner が呼ぶ
# --------------------------------------------------
func set_face_textures(left_tex:Texture2D, right_tex:Texture2D = null) -> void:
  _face_left.texture = left_tex
  if right_tex:
    _face_right.texture = right_tex
    _face_right.show()
  else:
    _face_right.hide()

func show_line(line: DialogueLine) -> void:
  _prepare_typing(line.text)
  _apply_highlight(line.speaker_side)
  _set_box_direction(line.box_direction)

func fade_in(box_direction: String = "left"):
  visible = true
  self.modulate.a = 0.0

  # スタート位置を外側へ
  _face_left.position  = _left_home  + Vector2(-slide_distance_face, 0)
  _face_right.position = _right_home + Vector2( slide_distance_face, 0)
  _box.position = _box_home + Vector2(0, slide_distance_box) # フキダシは下へずらす

  if box_direction == "left":
    _box.scale.x = 2.0 # フキダシの向きは左側
    _label.position = _label_home
  else: # "right"
    _box.scale.x = -2.0 # フキダシの向きは右側
    _box.position.x = -_box_home.x # フキダシ位置を反転
    _label.position.x = _label_home.x - 256 # ラベル位置を調整

  _click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

  var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tw.parallel().tween_property(self, "modulate:a", 1.0, fade_time)
  tw.parallel().tween_property(_face_left,  "position", _left_home,  fade_time)
  tw.parallel().tween_property(_face_right, "position", _right_home, fade_time)

  if box_direction == "left":
    tw.parallel().tween_property(_box, "position", _box_home, fade_time)
  else: # "right"
    tw.parallel().tween_property(_box, "position", Vector2(-_box_home.x, _box_home.y), fade_time)

  await tw.finished

  _click_area.mouse_filter = Control.MOUSE_FILTER_STOP

func fade_out():
  _label.text = ""  # テキストをクリア
  _click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

  var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(self, "modulate:a", 0.0, fade_time)
  tw.parallel().tween_property(_face_left,  "position", _left_home  + Vector2(-slide_distance_face, 0), fade_time)
  tw.parallel().tween_property(_face_right, "position", _right_home + Vector2(slide_distance_face, 0), fade_time)

  if _box.scale.x > 0: # フキダシの向きが左側
    tw.parallel().tween_property(_box, "position", _box_home + Vector2(0, slide_distance_box), fade_time)
  else: # フキダシの向きが右側
    tw.parallel().tween_property(_box, "position", Vector2(-_box_home.x, _box_home.y) + Vector2(0, slide_distance_box), fade_time)
  await tw.finished

  visible = false
  _click_area.mouse_filter = Control.MOUSE_FILTER_STOP

#=================================================
# Typing logic
#=================================================
func _prepare_typing(text:String) -> void:
  # 既存タイマーがあれば破棄
  if _timer:
    _timer = null
  _full_text = text
  _char_idx  = 0
  _label.text = ""
  _is_typing = true
  _schedule_next_char()

func _schedule_next_char() -> void:
  if _char_idx >= _full_text.length():
    _is_typing = false
    return
  _timer = get_tree().create_timer(char_interval)
  _timer.timeout.connect(_on_char_timer)

func _on_char_timer() -> void:
  _char_idx += 1
  _label.text = _full_text.substr(0, _char_idx)
  _schedule_next_char()

# --------------------------------------------------
# internal helper
# --------------------------------------------------
func _apply_highlight(speaker_side:String) -> void:
  if speaker_side == "left":
    _face_left.modulate = Color(1, 1, 1, highlight_alpha)
    _face_right.modulate = Color(1, 1, 1, dim_alpha)
  elif speaker_side == "right":
    _face_left.modulate = Color(1, 1, 1, dim_alpha)
    _face_right.modulate = Color(1, 1, 1, highlight_alpha)
  elif speaker_side == "both":
    _face_left.modulate = Color(1, 1, 1, highlight_alpha)
    _face_right.modulate = Color(1, 1, 1, highlight_alpha)
  else: # "none"
    _face_left.modulate = Color(1, 1, 1, dim_alpha)
    _face_right.modulate = Color(1, 1, 1, dim_alpha)

func _set_box_direction(direction:String) -> void:
  if direction == "left":
    _box.scale.x = 2.0
    _box.position = _box_home
    _label.position = _label_home
  else: # "right"
    _box.scale.x = -2.0
    _box.position.x = -_box_home.x
    _label.position.x = _label_home.x - 256

#=================================================
# Click handling (whole screen)
#=================================================
func _on_click_area_input(event:InputEvent) -> void:
  if event is InputEventMouseButton and event.pressed:
    _handle_click()
  elif event is InputEventKey and event.pressed and event.scancode == KEY_SPACE:
    _handle_click()

func _handle_click() -> void:
  if _is_typing:
    # 途中なら全文即表示
    if _timer:
      _timer.timeout.disconnect(_on_char_timer)
    _is_typing = false
    _label.text = _full_text
  else:
    emit_signal("advance_requested")
