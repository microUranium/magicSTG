# パターン化された敵AIのベースクラス
extends EnemyAIBase
class_name EnemyPatternedAIBase

@export var patterns: Array[EnemyPatternResource] = []  # パターンのリスト
@export var loop_type: int = 0  # 0 = SEQ, 1 = RANDOM

var _idx: int = 0
var _current: EnemyPatternResource
var _token: int = 0
var _active_tw: Tween = null


func _ready():
  super._ready()
  _next_pattern()


func _next_pattern():
  _current = (
    patterns[randi() % patterns.size()] if loop_type == 1 else patterns[_idx % patterns.size()]
  )

  if loop_type == 0:
    _idx += 1

  _token += 1
  _active_tw = _current.start(enemy_node, self, Callable(self, "_on_pattern_finished").bind(_token))


func _on_pattern_finished(cb_token: int) -> void:
  if cb_token != _token:  # 古いパターンは無視
    return
  _next_pattern()


func _cancel_current_pattern() -> void:
  if _active_tw and _active_tw.is_valid():
    _active_tw.kill()
  _active_tw = null
  _token += 1
