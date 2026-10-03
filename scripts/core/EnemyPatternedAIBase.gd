# パターン化された敵AIのベースクラス
extends EnemyAIBase
class_name EnemyPatternedAIBase

@warning_ignore("unused_signal")
signal phase_changed(phase_idx: int)  # フェーズ遷移をHPバー等へ通知（各ボスAIの _next_phase で emit）

@export var patterns: Array[EnemyPatternResource] = []  # パターンのリスト
@export var loop_type: int = 0  # 0 = SEQ, 1 = RANDOM
@export var skip_dialogue: bool = false  # ダイアログをスキップするかどうか
@export var skip_bgm_change: bool = false  # BGM変更をスキップするかどうか

var _idx: int = 0
var _current: EnemyPatternResource
var _token: int = 0
var _active_tw: Tween = null
var _last_movement_direction: Vector2 = Vector2.ZERO  # 前回の移動方向を記憶
var _stage_lifecycle: StageLifecycleController = null
var _player_control_blocked: bool = false  # 演出パターンによる操作ロック中か


func _ready():
  super._ready()
  _stage_lifecycle = (
    get_tree().root.get_node_or_null("Main/LifecycleController") as StageLifecycleController
  )
  if _stage_lifecycle == null:
    print_debug("EnemyPatternedAIBase: StageLifecycleController not found in scene tree")
  _next_pattern()


func _next_pattern():
  if _stage_lifecycle and not _stage_lifecycle.is_stage_running():
    print_debug("EnemyPatternedAIBase: Stage not running, skipping pattern execution")
    return

  _current = (
    patterns[randi() % patterns.size()] if loop_type == 1 else patterns[_idx % patterns.size()]
  )

  if loop_type == 0:
    _idx += 1

  _token += 1

  # 演出パターン中は会話中と同様にプレイヤー操作を止める
  _set_player_control_blocked(_current.block_player_control)

  if _current.dialogue_path != "" and skip_dialogue:
    _on_pattern_finished(_token)  # ダイアログをスキップしてパターン完了を通知
    return

  _active_tw = _current.start(enemy_node, self, Callable(self, "_on_pattern_finished").bind(_token))


func _on_pattern_finished(cb_token: int) -> void:
  print_debug("Pattern finished, token: ", cb_token, " current token: ", _token)
  if cb_token != _token:  # 古いパターンは無視
    return

  if _stage_lifecycle and not _stage_lifecycle.is_stage_running():
    print_debug("EnemyPatternedAIBase: Stage not running, skipping pattern execution")
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
  _set_player_control_blocked(false)


func _exit_tree() -> void:
  # 演出途中で敵が消えた場合に操作ロックが残らないようにする
  _set_player_control_blocked(false)


func _set_player_control_blocked(blocked: bool) -> void:
  """演出によるプレイヤー操作ロックの ON/OFF"""
  if blocked:
    # 会話終了時に StageController 側で一括解除されるため、毎回ロックを掛け直す
    _player_control_blocked = true
    StageSignals.emit_cutscene_pause_requested(true)
    return

  if not _player_control_blocked:
    return
  _player_control_blocked = false

  # ステージ終了時はステージ側がポーズ状態を管理するため、ここでは解除しない
  if is_instance_valid(_stage_lifecycle) and not _stage_lifecycle.is_stage_running():
    return
  StageSignals.emit_cutscene_pause_requested(false)
