extends TextureRect

@export var flash_color: Color = Color(1, 1, 1, 1)  # Default red color with some transparency


func _ready():
  # Set the initial color and visibility
  self.modulate = flash_color
  self.visible = false

  StageSignals.request_hud_flash.connect(_flash)


func _flash(_fade_duration: float = 0.2):
  self.visible = true
  self.modulate = flash_color

  var tw = create_tween()
  tw.tween_property(self, "modulate", Color(1, 1, 1, 0), _fade_duration)
  tw.play()
