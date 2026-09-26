# === 敵の追跡移動と迷彩の加護 ===
# 自機を追う移動AIは、迷彩中は本体ではなく囮座標へ向かわなければならない。
# （ハーピーのバリア弾と同じく、ターゲットノードの実座標を直接読んでいた箇所の回帰テスト）
class_name EnemyChaseCamouflageTest
extends GdUnitTestSuite

const StraightMoveAI := preload("res://scripts/enemy/StraightMoveAI.gd")
const DistanceKeepingAI := preload("res://scripts/enemy/DistanceKeepingAI.gd")

const ENEMY_POS := Vector2(400, 100)
const PLAYER_POS := Vector2(400, 700)  # 敵の真下
const DECOY_POS := Vector2(100, 700)  # 敵の左下

var _scene: Node2D
var _player: Node2D
var _enemy: Node2D


func before_test() -> void:
  _scene = auto_free(Node2D.new())
  add_child(_scene)

  # これらのAIは TargetService から自機を取得する（シーン内の "Player" 名には依存しない）
  _player = auto_free(Node2D.new())
  _player.add_to_group("players")
  _scene.add_child(_player)
  _player.global_position = PLAYER_POS
  TargetService.register_player(_player)

  _enemy = auto_free(Node2D.new())
  _enemy.add_to_group("enemies")
  _scene.add_child(_enemy)
  _enemy.global_position = ENEMY_POS


func after_test() -> void:
  TargetService.set_player_targetable(true)
  TargetService.unregister_player()


## 敵ノードの子として AI を生成し、フレームは手動で進める
func _make_ai(script: GDScript) -> Node:
  var ai: Node = auto_free(script.new())
  _enemy.add_child(ai)
  ai.set_process(false)
  return ai


func _move_direction(ai: Node) -> Vector2:
  var start_pos := _enemy.global_position
  ai._process(0.1)
  return (_enemy.global_position - start_pos).normalized()


func test_straight_move_follows_player() -> void:
  var ai := _make_ai(StraightMoveAI)
  ai.viewport_half_y = 10000.0  # 画面下半分への移動制限を無効化

  var moved := _move_direction(ai)

  assert_vector(moved).is_equal_approx((PLAYER_POS - ENEMY_POS).normalized(), Vector2(0.01, 0.01))


func test_straight_move_follows_decoy_while_camouflaged() -> void:
  var ai := _make_ai(StraightMoveAI)
  ai.viewport_half_y = 10000.0
  TargetService.set_player_targetable(false, DECOY_POS)

  var moved := _move_direction(ai)

  assert_vector(moved).is_equal_approx((DECOY_POS - ENEMY_POS).normalized(), Vector2(0.01, 0.01))


func test_distance_keeping_approaches_player() -> void:
  var ai := _make_ai(DistanceKeepingAI)

  var moved := _move_direction(ai)

  # 目標距離より遠いので近づく方向へ動く
  assert_vector(moved).is_equal_approx((PLAYER_POS - ENEMY_POS).normalized(), Vector2(0.01, 0.01))


func test_distance_keeping_approaches_decoy_while_camouflaged() -> void:
  var ai := _make_ai(DistanceKeepingAI)
  TargetService.set_player_targetable(false, DECOY_POS)

  var moved := _move_direction(ai)

  assert_vector(moved).is_equal_approx((DECOY_POS - ENEMY_POS).normalized(), Vector2(0.01, 0.01))
