extends "res://scripts/player/ProjectileBullet.gd"
class_name HarpyBulletBarrier

@export var owner_path: NodePath
@export var bullet_group: String
@export var circle_radius := 50.0
@export var rotation_duration := 3.0  # 回転継続時間
@export var circle_rotate_speed: float = 90.0  # 度/秒

var owner_node: Node2D
var target_node: Node2D = null
var offset: Vector2 = Vector2.ZERO
var circle_angle: float = 0.0
var is_projectile: bool = false  # プロジェクタイルかどうか
var bullet_number: int
var bullet_amount: int
var current_circle_radius: float = 0.0

func _ready():
  super._ready()

  if not bullet_group.is_empty():
    add_to_group(bullet_group)
  if owner_path != NodePath():
    owner_node = get_node(owner_path)

func start():
  get_tree().create_timer(rotation_duration).timeout.connect(_on_timeout)

  var _tween := create_tween()
  _tween.tween_property(self, "current_circle_radius", circle_radius, 0.5)
  _tween.play()

func _process(delta):
  if not PlayArea.get_play_rect().has_point(global_position) or owner_node == null:
    queue_free()

  if not is_projectile: # プロジェクタイルでない場合は円形の動き
    circle_angle = wrapf(
      circle_angle + circle_rotate_speed * delta,
      0.0, 360.0)
    _recalc_offset_for(bullet_amount, bullet_number)
    if owner_node:
      global_position = owner_node.global_position + offset
  else:  # プロジェクタイルの場合は直進
    position += direction * speed * delta

func _recalc_offset_for(amount: int, idx: int) -> void:
  var total: int = max(amount, 1)   # 0 除算対策

  var ballet_angle := 360.0 * idx / total
  var angle_rad  := deg_to_rad(ballet_angle + circle_angle)
  offset = Vector2(0, -current_circle_radius).rotated(angle_rad)

func _on_timeout():
  is_projectile = true
  if target_node:
    direction = (target_node.global_position - global_position).normalized()
