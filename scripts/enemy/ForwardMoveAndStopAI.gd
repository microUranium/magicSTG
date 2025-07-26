extends EnemyAIBase

@export var turn_rate: float = 5.0
@export var deceleration_time: float = 3  # 速度減衰時間
@export var min_speed: float = 0  # 最低速度

var speed: float
var direction: Vector2 = Vector2.DOWN


func _ready():
  super._ready()
  speed = base_speed

  var tw = get_tree().create_tween()
  tw.tween_property(self, "speed", min_speed, deceleration_time)

  tw.play()


func _process(delta):
  if enemy_node:
    enemy_node.position += direction * speed * delta
