class_name PlayerMovementTest
extends GdUnitTestSuite

@onready var player_scene := preload("res://scenes/player/player.tscn")

var _player: Node2D
var _saved_play_rect: Rect2


func before_test():
  # headless ではプレイ領域が負の幅になり、移動後の位置クランプで左へ押し出されるため固定する
  _saved_play_rect = PlayArea.get_play_rect()
  PlayArea._play_rect = Rect2(0, 0, 896, 960)
  _player = player_scene.instantiate()
  add_child(_player)  # SceneRunner が不要なシンプル例


func after_test():
  PlayArea._play_rect = _saved_play_rect


func test_moves_right_on_input():
  _player.direction = Vector2.RIGHT
  _player._process(0.1)
  assert_float(_player.position.x).is_greater(0)
