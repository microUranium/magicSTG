extends Node

signal player_registered(player: Node2D)
signal player_unregistered

var _current_player: Node2D = null
var _bullet_parent: Node = null


func register_player(player: Node2D) -> void:
  if _current_player != player:
    _current_player = player
    emit_signal("player_registered", player)


func unregister_player() -> void:
  _current_player = null
  emit_signal("player_unregistered")


func get_player() -> Node2D:
  return _current_player


func get_player_position() -> Vector2:
  return _current_player.global_position if _current_player else Vector2.ZERO


func set_bullet_parent(parent: Node) -> void:
  _bullet_parent = parent


func get_bullet_parent() -> Node:
  return _bullet_parent if _bullet_parent else get_tree().current_scene
