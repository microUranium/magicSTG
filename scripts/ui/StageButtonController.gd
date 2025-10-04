extends Control
class_name StageButtonController

signal stage_selected(stage_data: StageData)

@export var stage_data: StageData
var dialogue_enabled: bool = true

@onready var button_parent: Control = $Control
@onready var stage_name_label: Label = $Control/StageName
@onready var dialogue_toggle: Button = $Control/DialogueSwitchButton
@onready var lock_overlay: Control = $Control/LockOverlay
@onready var stage_button: Button = $Control/StageButton


func _ready() -> void:
  if stage_button:
    stage_button.pressed.connect(_on_stage_button_pressed)
  if dialogue_toggle:
    dialogue_toggle.pressed.connect(_on_dialogue_toggle_pressed)


func setup_stage_data(data: StageData, fade_direction: Vector2) -> void:
  if not stage_name_label or not stage_button or not dialogue_toggle or not lock_overlay:
    await ready

  stage_data = data
  dialogue_enabled = data.dialogue_enabled if data else true
  button_fade_in(fade_direction)
  update_display()


func update_display() -> void:
  if not stage_data:
    return

  if stage_name_label:
    stage_name_label.text = stage_data.stage_name

  var is_locked = not stage_data.is_unlocked

  if lock_overlay:
    lock_overlay.visible = is_locked

  if stage_button:
    stage_button.disabled = is_locked

  if dialogue_toggle:
    dialogue_toggle.disabled = is_locked
    update_dialogue_icon()


func update_dialogue_icon() -> void:
  if not dialogue_toggle:
    return

  var icon_path = (
    "res://assets/gfx/sprites/dialogue_enable.png"
    if dialogue_enabled
    else "res://assets/gfx/sprites/dialogue_disable.png"
  )
  if ResourceLoader.exists(icon_path):
    dialogue_toggle.icon = load(icon_path)


func _on_stage_button_pressed() -> void:
  if stage_data and stage_data.can_start():
    stage_selected.emit(stage_data)


func _on_dialogue_toggle_pressed() -> void:
  dialogue_enabled = not dialogue_enabled
  if stage_data:
    stage_data.dialogue_enabled = dialogue_enabled
  update_dialogue_icon()


func set_selected(selected: bool) -> void:
  modulate = Color.YELLOW if selected else Color.WHITE


func button_fade_in(direction: Vector2) -> void:
  if not button_parent:
    return

  var default_pos = button_parent.position
  button_parent.position = default_pos + Vector2(1200, 0) * direction

  var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween.tween_property(button_parent, "position", default_pos, 0.3)
  tween.play()


func button_fade_out(direction: Vector2) -> void:
  if not button_parent:
    return

  var default_pos = button_parent.position
  var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tween.tween_property(button_parent, "position", default_pos + Vector2(1200, 0) * direction, 0.3)
  tween.play()

  await tween.finished
  queue_free()
