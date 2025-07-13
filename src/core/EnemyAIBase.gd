extends Node

@export var base_speed: float = 100.0

var enemy_node: Node2D

func _ready():
  enemy_node = get_parent()
  if enemy_node == null:
    push_warning("EnemyAI.gd: 親Node2Dが存在しません。")
