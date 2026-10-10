# 5-1 熊ボスの登場演出（会話 → 自機が近づく → 起動 → 後ずさり）の結合テスト
extends GdUnitTestSuite

const BEAR_SCENE := preload("res://scenes/enemy/enemy_boss_bear.tscn")

var _bear: Node2D
var _player_stub: _StubPlayer


func before_test():
  _player_stub = _StubPlayer.new()
  add_child(_player_stub)
  TargetService.register_player(_player_stub)

  StageSignals.request_dialogue.connect(_on_request_dialogue)

  _bear = BEAR_SCENE.instantiate()
  add_child(_bear)
  await await_idle_frame()


func after_test():
  if StageSignals.request_dialogue.is_connected(_on_request_dialogue):
    StageSignals.request_dialogue.disconnect(_on_request_dialogue)
  TargetService.unregister_player()
  if is_instance_valid(_bear):
    _bear.queue_free()
  if is_instance_valid(_player_stub):
    _player_stub.queue_free()


func _on_request_dialogue(_dd, finished_cb: Callable) -> void:
  if finished_cb.is_valid():
    finished_cb.call_deferred()


func _sprite() -> AnimatedSprite2D:
  return _bear.get_node("AnimatedSprite2D") as AnimatedSprite2D


func test_animation_is_stopped_until_conversation_ends(timeout := 20000) -> void:
  # 登場〜会話中は眠ったままアニメーションを止めておく
  assert_bool(_sprite().is_playing()).is_false()

  # 会話の後に自機がボスへ近づく
  await await_millis(2600)
  assert_bool(_sprite().is_playing()).is_false()
  assert_vector(_player_stub.last_target).is_equal(_bear.global_position + Vector2(0, 280))

  # 近づき終わるとボスが目を覚ます
  await await_millis(1200)
  assert_bool(_sprite().is_playing()).is_true()

  # その後に自機が画面中央へ後ずさり、2回目の会話を経て戦闘フェーズへ進む
  await await_millis(1200)
  assert_vector(_player_stub.last_target).is_equal(Vector2(448, 480))
  assert_int(_bear.ai._phase_idx).is_equal(1)


class _StubPlayer:
  extends Node2D

  var last_target: Vector2 = Vector2.ZERO

  func move_to(target_position: Vector2, duration: float) -> Tween:
    last_target = target_position
    if duration <= 0.0:
      global_position = target_position
      return null
    var tween := create_tween()
    tween.tween_property(self, "global_position", target_position, duration)
    return tween
