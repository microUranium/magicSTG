extends Node2D

@export var player_path: NodePath
@export var offset: Vector2 = Vector2(30, 0)  # プレイヤーからの相対位置

@onready var slot := $AttackCoreSlot
var player: Node2D


func _ready():
  pass


func _process(_delta):
  if player:
    global_position = player.global_position + offset
  else:
    queue_free()


func set_player_path(path: NodePath) -> void:
  player_path = path
  player = get_node_or_null(player_path)
  if player == null:
    push_warning("Fairy: Failed to set player_path. Node not found: " + str(path))
  else:
    global_position = player.global_position + offset
