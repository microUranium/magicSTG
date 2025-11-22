extends Control
class_name StageSelectController

var current_chapter_index: int = 0
var prev_chapter_index: int = -1
var selected_stage: StageData = null
var stage_buttons: Array[StageButtonController] = []
var button_cooldown_timer: Timer = null

@onready var chapter_name_label: Label = $ChapterSelectContainer/MarginContainer/ChapterName
@onready var stage_container: Control = $VBoxContainer
@onready var chapter_prev_btn: Button = $ChapterSelectContainer/Control/ChapterChangeBack
@onready var chapter_next_btn: Button = $ChapterSelectContainer/Control2/ChapterChangeNext
@onready var to_equpment_btn: Button = $ToEquipSceneButton
@onready var to_main_menu_btn: Button = $ReturnButton


func _ready() -> void:
  # Setup cooldown timer
  button_cooldown_timer = Timer.new()
  button_cooldown_timer.wait_time = 0.5
  button_cooldown_timer.one_shot = true
  button_cooldown_timer.timeout.connect(_on_button_cooldown_timeout)
  add_child(button_cooldown_timer)

  if chapter_prev_btn:
    chapter_prev_btn.pressed.connect(_on_chapter_prev_pressed)
  if chapter_next_btn:
    chapter_next_btn.pressed.connect(_on_chapter_next_pressed)
  if to_equpment_btn:
    to_equpment_btn.pressed.connect(_on_equipment_button_pressed)
  if to_main_menu_btn:
    to_main_menu_btn.pressed.connect(_on_return_button_pressed)

  StageDataManager.stage_data_loaded.connect(_on_stage_data_loaded)

  if StageDataManager.stage_select_data:
    _on_stage_data_loaded()


func _on_stage_data_loaded() -> void:
  var chapters = StageDataManager.get_unlocked_chapters()
  if chapters.is_empty():
    push_warning("No unlocked chapters found")
    return

  current_chapter_index = 0
  update_chapter_display()


func update_chapter_display() -> void:
  var chapters = StageDataManager.get_unlocked_chapters()
  if chapters.is_empty() or current_chapter_index >= chapters.size():
    return

  var current_chapter = chapters[current_chapter_index]

  if chapter_name_label:
    chapter_name_label.text = current_chapter.chapter_name

  StageSignals.request_background_change.emit(current_chapter.background_texture)
  populate_stage_buttons(current_chapter)


func _update_chapter_button_states() -> void:
  var chapters = StageDataManager.get_unlocked_chapters()
  if chapter_prev_btn:
    chapter_prev_btn.disabled = (current_chapter_index <= 0)
  if chapter_next_btn:
    chapter_next_btn.disabled = (current_chapter_index >= chapters.size() - 1)


func populate_stage_buttons(chapter: ChapterData) -> void:
  var fade_direction: Vector2
  if current_chapter_index >= prev_chapter_index:
    fade_direction = Vector2(1, 0)
  else:
    fade_direction = Vector2(-1, 0)

  await clear_stage_buttons(fade_direction * -1)

  var stage_button_scene = preload("res://scenes/ui/select_stage_container.tscn")

  for stage in chapter.stages:
    var stage_button_instance = stage_button_scene.instantiate()
    var controller = stage_button_instance.get_script()

    if not controller:
      var stage_controller = StageButtonController.new()
      stage_button_instance.set_script(stage_controller)
      controller = stage_controller

    controller = stage_button_instance as StageButtonController
    if controller:
      controller.setup_stage_data(stage, fade_direction)
      controller.stage_selected.connect(_on_stage_selected)
      stage_buttons.append(controller)

    if stage_container:
      stage_container.add_child(stage_button_instance)


func clear_stage_buttons(fade_direction: Vector2) -> void:
  stage_buttons.clear()
  if stage_container:
    for child in stage_container.get_children():
      if not child is StageButtonController:
        continue
      child.button_fade_out(fade_direction)
  await get_tree().create_timer(0.35).timeout


func _disable_chapter_buttons() -> void:
  if chapter_prev_btn:
    chapter_prev_btn.disabled = true
  if chapter_next_btn:
    chapter_next_btn.disabled = true


func _on_button_cooldown_timeout() -> void:
  _update_chapter_button_states()


func _on_chapter_prev_pressed() -> void:
  if current_chapter_index > 0:
    prev_chapter_index = current_chapter_index
    current_chapter_index -= 1
    _disable_chapter_buttons()
    update_chapter_display()
    button_cooldown_timer.start()


func _on_chapter_next_pressed() -> void:
  var chapters = StageDataManager.get_unlocked_chapters()
  if current_chapter_index < chapters.size() - 1:
    prev_chapter_index = current_chapter_index
    current_chapter_index += 1
    _disable_chapter_buttons()
    update_chapter_display()
    button_cooldown_timer.start()


func _on_stage_selected(stage_data: StageData) -> void:
  if selected_stage:
    var old_button = find_stage_button(selected_stage)
    if old_button:
      old_button.set_selected(false)

  selected_stage = stage_data
  var new_button = find_stage_button(stage_data)
  if new_button:
    new_button.set_selected(true)

  StageDataManager.start_stage(stage_data)


func find_stage_button(stage_data: StageData) -> StageButtonController:
  for button in stage_buttons:
    if button.stage_data == stage_data:
      return button
  return null


func _on_equipment_button_pressed() -> void:
  GameFlow.start_equipment_screen()


func _on_return_button_pressed() -> void:
  GameFlow.change_to_title()
