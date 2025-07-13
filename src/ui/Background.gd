extends ParallaxBackground

@export var scroll_speed: float = 100.0

@export var sprite: Sprite2D

var background_width: float = 0.0

func _ready() -> void:
  if sprite:
    background_width = sprite.texture.get_size().x * sprite.scale.x

  if PlayArea.get_play_rect().size.x <= background_width:
    sprite.position.x = -(background_width - PlayArea.get_play_rect().size.x) / 2

  StageSignals.request_change_background_scroll_speed.connect(_change_scroll_speed)
  StageSignals.request_start_vibration.connect(_start_vibration)

func _process(delta: float) -> void:
  scroll_offset.y += scroll_speed * delta

func _change_scroll_speed(new_speed: float, change_time: float) -> void:
  var tween = create_tween()
  tween.tween_property(self, "scroll_speed", new_speed, change_time)
  tween.play()

func _start_vibration() -> void:
  var default_pos = sprite.position.x if sprite else 0
  var vibration_pos_min = -(background_width - PlayArea.get_play_rect().size.x)
  var vibration_pos_max = 0

  if sprite:
    var tween = create_tween()
    tween.tween_property(sprite, "position:x", vibration_pos_min, 0)
    tween.tween_interval(0.1)
    tween.tween_property(sprite, "position:x", vibration_pos_max, 0)
    tween.tween_interval(0.1)
    tween.tween_property(sprite, "position:x", (2 * default_pos + vibration_pos_min) / 3, 0)
    tween.tween_interval(0.1)
    tween.tween_property(sprite, "position:x", (2 * default_pos + vibration_pos_max) / 3, 0)
    tween.tween_interval(0.1)
    tween.tween_property(sprite, "position:x", default_pos, 0)
    tween.play()
