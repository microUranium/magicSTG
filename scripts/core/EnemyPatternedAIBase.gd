# パターン化された敵AIのベースクラス
extends EnemyAIBase
class_name EnemyPatternedAIBase

@export var patterns: Array[EnemyPatternResource] = []  # パターンのリスト
@export var loop_type: int = 0  # 0 = SEQ, 1 = RANDOM
@export var skip_dialogue: bool = false  # ダイアログをスキップするかどうか
@export var skip_bgm_change: bool = false  # BGM変更をスキップするかどうか

var _idx: int = 0
var _current: EnemyPatternResource
var _token: int = 0
var _active_tw: Tween = null
var _last_movement_direction: Vector2 = Vector2.ZERO  # 前回の移動方向を記憶


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

  if _current.dialogue_path != "" and skip_dialogue:
    _on_pattern_finished(_token)  # ダイアログをスキップしてパターン完了を通知
    return

  _active_tw = _current.start(enemy_node, self, Callable(self, "_on_pattern_finished").bind(_token))


func _on_pattern_finished(cb_token: int) -> void:
  print_debug("Pattern finished, token: ", cb_token, " current token: ", _token)
  if cb_token != _token:  # 古いパターンは無視
    return
  _next_pattern()


func get_last_movement_direction() -> Vector2:
  return _last_movement_direction


func set_last_movement_direction(direction: Vector2) -> void:
  _last_movement_direction = direction.normalized()
  print_debug("EnemyPatternedAIBase: Stored movement direction: ", _last_movement_direction)


func _cancel_current_pattern() -> void:
  if _active_tw and _active_tw.is_valid():
    _active_tw.kill()
  _active_tw = null
  _token += 1
