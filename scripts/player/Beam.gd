extends Area2D

@export var damage: int = 1
@export var desired_length: float = 1000.0
@export var owner_path: NodePath  # 精霊への参照
@export var enemy_group: String = "enemies"
@export var damage_tick_sec: float = 1.0 / 30.0

var owner_node: Node2D

@onready var ninepatch: NinePatchRect = $NinePatchRect
@onready var shape: RectangleShape2D = $CollisionShape2D.shape
@onready var raycast: RayCast2D = $RayCast2D
@onready var dmg_timer: Timer = $DamageTimer


func _ready():
  raycast.target_position = Vector2(0, -desired_length)
  raycast.enabled = true
  raycast.exclude_parent = true

  dmg_timer.wait_time = damage_tick_sec
  dmg_timer.timeout.connect(_on_damage_tick)
  dmg_timer.start()

  _apply_length(desired_length)

  if owner_path != NodePath():
    owner_node = get_node(owner_path)


func initialize(_owner_node: Node2D, _damage: int, _beam_direction: Vector2) -> void:
  """ビームの初期化"""
  self.owner_node = _owner_node
  self.damage = _damage


func _process(_delta: float) -> void:
  if owner_node:
    global_position = owner_node.global_position

  var length := desired_length
  if raycast.is_colliding():
    var col := raycast.get_collider()
    if col and col.is_in_group(enemy_group):
      length = global_position.distance_to(raycast.get_collision_point())

  _apply_length(length)


func _apply_length(length: float) -> void:
  # 視覚
  ninepatch.size.y = length
  ninepatch.position.y = -length
  # コリジョン
  shape.extents.y = length * 0.5
  $CollisionShape2D.position.y = -length * 0.5


func _on_damage_tick() -> void:
  StageSignals.sfx_play_requested.emit("shot_beam", global_position, 0, 1.0)
  if !raycast.is_colliding():
    return

  var enemy := raycast.get_collider()
  if enemy == null or !enemy.is_in_group(enemy_group):
    return

  if enemy.has_method("take_damage"):
    enemy.take_damage(damage)
