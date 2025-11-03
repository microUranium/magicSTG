extends EnemyAIBase
class_name OrbitAI

@export var owner_node: Node2D = null
@export var orbit_radius: float = 100.0
@export var rotation_speed: float = 2.0
@export var rotate_sprite: bool = false

var current_angle: float = 0.0


func _ready():
  super._ready()


func _process(delta):
  if enemy_node and owner_node:
    current_angle += rotation_speed * delta

    var orbit_position = Vector2(
      cos(current_angle) * orbit_radius, sin(current_angle) * orbit_radius
    )

    enemy_node.global_position = owner_node.global_position + orbit_position

    if rotate_sprite:
      enemy_node.rotation = current_angle + PI / 2  # Adjust rotation to face outward


func set_owner_node(node: Node2D):
  owner_node = node


func set_orbit_radius(radius: float):
  orbit_radius = radius


func set_rotation_speed(speed: float):
  rotation_speed = speed


func set_initial_angle(angle: float):
  current_angle = angle
