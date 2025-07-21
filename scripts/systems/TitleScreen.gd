extends Control

@onready var switch_to_equipment_button: Button = $SwitchToEquipmentButton


func _ready() -> void:
  switch_to_equipment_button.pressed.connect(_on_switch_to_equipment_pressed)


func _unhandled_input(event: InputEvent) -> void:
  if event.is_pressed():
    GameFlow.start_stage()


func _on_switch_to_equipment_pressed() -> void:
  GameFlow.start_equipment_screen()
