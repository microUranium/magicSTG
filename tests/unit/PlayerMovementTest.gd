class_name PlayerMovementTest
extends GdUnitTestSuite

@onready var player_scene := preload("res://scenes/player/player.tscn")

var _player: Node2D


func before_test():
  _player = player_scene.instantiate()
  add_child(_player)  # SceneRunner が不要なシンプル例


func test_moves_right_on_input():
  _player.direction = Vector2.RIGHT
  _player._process(0.1)
  assert_float(_player.position.x).is_greater(0)
