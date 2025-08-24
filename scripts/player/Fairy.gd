extends Node2D

@export var player_path: NodePath
@export var offset: Vector2 = Vector2(30, 0)  # プレイヤーからの相対位置
@export var sprite_forward: Texture2D
@export var sprite_rear: Texture2D

@onready var slot := $AttackCoreSlot
@onready var sprite2D := $Sprite2D
var player: Node2D


func _ready():
  sprite2D.texture = sprite_forward


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


func set_firing_sprite(rear_mode: bool) -> void:
  if rear_mode:
    sprite2D.texture = sprite_rear
  else:
    sprite2D.texture = sprite_forward
