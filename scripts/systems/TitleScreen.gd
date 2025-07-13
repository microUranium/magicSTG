extends Control


func _unhandled_input(event: InputEvent) -> void:
  if event.is_pressed():
    GameFlow.start_stage()
