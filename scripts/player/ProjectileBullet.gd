extends BulletBase
class_name ProjectileBullet

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.UP
@export var deceleration_time: float = 3  # 速度減衰時間
@export var min_speed: float = 500.0  # 最低速度


func _ready():
  if speed > min_speed:
    var tw = get_tree().create_tween()
    tw.tween_property(self, "speed", min_speed, deceleration_time)
    tw.play()


func _process(delta):
  position += direction * speed * delta
  if not PlayArea.get_play_rect().has_point(global_position):
    queue_free()
