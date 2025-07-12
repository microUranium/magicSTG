extends "res://src/BulletBase.gd"

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.UP

func _process(delta):
  position += direction * speed * delta
  if not PlayArea.get_play_rect().has_point(global_position):
    queue_free()