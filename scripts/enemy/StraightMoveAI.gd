extends EnemyAIBase

@export var turn_rate: float = 5.0
@export var deceleration_rate: float = 10.0 # 速度減衰量 (per second)
@export var min_speed: float = 10.0 # 最低速度

var speed: float
var player_node: Node2D
var viewport_half_y: float

func _ready():
  super._ready()
  player_node = get_tree().current_scene.get_node("Player")
  viewport_half_y = get_viewport().get_visible_rect().size.y / 2
  speed = base_speed

func _process(delta):
  if enemy_node and player_node:
    var direction = (player_node.global_position - enemy_node.global_position).normalized()
        
    # 次に移動する位置を計算
    var next_position = enemy_node.position + direction * speed * delta
        
    # 画面半分より下には移動させない
    if next_position.y > viewport_half_y:
      next_position.y = viewport_half_y
        
    enemy_node.position = next_position

    # 速度を徐々に低下させる
    speed -= deceleration_rate * delta
    if speed < min_speed:
      speed = min_speed
