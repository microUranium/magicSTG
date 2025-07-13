extends Area2D

@export var damage: int = 1
@export var desired_length: float = 300.0
@export var owner_path: NodePath  # 精霊への参照

var owner_node: Node2D


func _ready():
  var ninepatch = $NinePatchRect
  ninepatch.size.y = desired_length
  ninepatch.position.y = -desired_length

  var shape = $CollisionShape2D.shape
  shape.extents.y = desired_length / 2
  $CollisionShape2D.position.y = -desired_length / 2

  if owner_path != NodePath():
    owner_node = get_node(owner_path)


func initialize(_owner_node: Node2D):
  self.owner_node = _owner_node


func _process(_delta):
  if owner_node:
    global_position = owner_node.global_position
