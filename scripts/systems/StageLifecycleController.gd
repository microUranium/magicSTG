extends Node
class_name StageLifecycleController

signal stage_initialization_started
signal stage_initialization_completed
signal stage_cleared
signal stage_failed

#---------------------------------------------------------------------
# Stage States
#---------------------------------------------------------------------
enum StageState { UNINITIALIZED, INITIALIZING, RUNNING, PAUSED, CLEARING, FAILED, COMPLETED }

#---------------------------------------------------------------------
# Runtime
#---------------------------------------------------------------------
var _current_state: StageState = StageState.UNINITIALIZED
var _is_initialized: bool = false

#---------------------------------------------------------------------
# Public Interface
#---------------------------------------------------------------------


func get_current_state() -> StageState:
  """現在のステージ状態を取得"""
  return _current_state


func is_initialized() -> bool:
  """初期化済みかチェック"""
  return _is_initialized


func is_stage_running() -> bool:
  """ステージが実行中かチェック"""
  return _current_state == StageState.RUNNING


func can_start_stage() -> bool:
  """ステージ開始可能かチェック"""
  return _current_state == StageState.UNINITIALIZED or _current_state == StageState.COMPLETED


#---------------------------------------------------------------------
# Lifecycle Management
#---------------------------------------------------------------------


func start_initialization() -> void:
  """ステージ初期化を開始"""
  if _is_initialized:
    push_warning("StageLifecycleController: Already initialized")
    return
  _current_state = StageState.INITIALIZING
  stage_initialization_started.emit()
  print_debug("StageLifecycleController: Initialization started")


func complete_initialization() -> void:
  """ステージ初期化を完了"""
  if _current_state != StageState.INITIALIZING:
    push_warning("StageLifecycleController: Not in initializing state")
    return
  _is_initialized = true
  _current_state = StageState.RUNNING
  stage_initialization_completed.emit()
  print_debug("StageLifecycleController: Initialization completed, stage running")


func handle_stage_cleared() -> void:
  """ステージクリア処理"""
  if _current_state != StageState.RUNNING:
    push_warning("StageLifecycleController: Stage not running, cannot clear")
    return

    # クリア処理の実行
  _current_state = StageState.CLEARING
  print_debug("StageLifecycleController: Stage clearing")

  # クリア処理の実行
  await _execute_clear_sequence()

  _current_state = StageState.COMPLETED
  stage_cleared.emit()
  print_debug("StageLifecycleController: Stage cleared")


func handle_stage_failed() -> void:
  """ステージ失敗処理"""
  if _current_state != StageState.RUNNING:
    push_warning("StageLifecycleController: Stage not running, cannot failed")
    return

  if _current_state == StageState.FAILED or _current_state == StageState.COMPLETED:
    push_warning("StageLifecycleController: Stage already finished")
    return

    # 失敗処理の実行
  _current_state = StageState.FAILED
  print_debug("StageLifecycleController: Stage failed")

  # 失敗処理の実行
  await _execute_failure_sequence()

  stage_failed.emit()
  print_debug("StageLifecycleController: Stage failure sequence completed")


func pause_stage() -> void:
  """ステージを一時停止"""
  if _current_state == StageState.RUNNING:
    _current_state = StageState.PAUSED
    print_debug("StageLifecycleController: Stage paused")


func resume_stage() -> void:
  """ステージを再開"""
  if _current_state == StageState.PAUSED:
    _current_state = StageState.RUNNING
    print_debug("StageLifecycleController: Stage resumed")


func reset_stage() -> void:
  """ステージをリセット"""
  _current_state = StageState.UNINITIALIZED
  _is_initialized = false
  print_debug("StageLifecycleController: Stage reset")


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------


func _execute_clear_sequence() -> void:
  """ステージクリア時のシーケンス処理"""
  # 将来的にクリア時の特別な処理を追加する場合はここに実装
  # 例: スコア計算、アイテム集計、次ステージの準備など
  pass


func _execute_failure_sequence() -> void:
  """ステージ失敗時のシーケンス処理"""
  # 将来的に失敗時の特別な処理を追加する場合はここに実装
  # 例: 失敗原因の記録、リトライ準備、統計データの更新など
  pass


#---------------------------------------------------------------------
# State Validation
#---------------------------------------------------------------------


func validate_state_transition(from: StageState, to: StageState) -> bool:
  """状態遷移が有効かチェック"""
  match from:
    StageState.UNINITIALIZED:
      return to == StageState.INITIALIZING
    StageState.INITIALIZING:
      return to == StageState.RUNNING or to == StageState.FAILED
    StageState.RUNNING:
      return to == StageState.PAUSED or to == StageState.CLEARING or to == StageState.FAILED
    StageState.PAUSED:
      return to == StageState.RUNNING or to == StageState.FAILED
    StageState.CLEARING:
      return to == StageState.COMPLETED
    StageState.FAILED, StageState.COMPLETED:
      return to == StageState.UNINITIALIZED
    _:
      return false


func get_state_name(state: StageState) -> String:
  """状態名を文字列で取得"""
  match state:
    StageState.UNINITIALIZED:
      return "UNINITIALIZED"
    StageState.INITIALIZING:
      return "INITIALIZING"
    StageState.RUNNING:
      return "RUNNING"
    StageState.PAUSED:
      return "PAUSED"
    StageState.CLEARING:
      return "CLEARING"
    StageState.FAILED:
      return "FAILED"
    StageState.COMPLETED:
      return "COMPLETED"
    _:
      return "UNKNOWN"
