# DialogueRunnerのテスト用モック
extends DialogueRunner
class_name MockDialogueRunner

# モック用の状態管理
var _is_running: bool = false
var _current_dialogue: DialogueData = null
var _current_callback: Callable


func start(dialogue_data) -> void:
  """ダイアログ開始のモック"""
  # null参照エラー防止
  if not dialogue_data:
    call_deferred("_finish_dialogue")
    return

  _current_dialogue = dialogue_data
  _is_running = true

  # テスト用：即座に完了をシミュレート
  call_deferred("_finish_dialogue")


func start_with_callback(dialogue_data, finished_cb: Callable) -> void:
  """コールバック付きダイアログ開始のモック"""
  _current_callback = finished_cb
  start(dialogue_data)


func start_dialogue_lines(dialogue_lines: Array) -> void:
  """ダイアログライン配列での開始のモック"""
  # null参照エラー防止
  if not dialogue_lines or dialogue_lines.is_empty():
    call_deferred("_finish_dialogue")
    return

  # DialogueDataクラスの存在確認してから作成
  var dialogue_data = null
  if ClassDB.class_exists("DialogueData"):
    dialogue_data = ClassDB.instantiate("DialogueData")
    if dialogue_data and dialogue_data.has_method("set") and "lines" in dialogue_data:
      dialogue_data.lines = dialogue_lines

  start(dialogue_data)


func _finish_dialogue():
  """ダイアログ完了のモック"""
  _is_running = false

  # シグナル発火
  dialogue_finished.emit(_current_dialogue)

  # コールバック実行
  if _current_callback and _current_callback.is_valid():
    _current_callback.call()
    _current_callback = Callable()

  _current_dialogue = null


# モック用のユーティリティメソッド
func is_running() -> bool:
  """実行中状態の確認"""
  return _is_running


func get_current_dialogue():
  """現在のダイアログデータ取得"""
  return _current_dialogue


func simulate_finish():
  """強制的にダイアログ完了をシミュレート"""
  if _is_running:
    _finish_dialogue()


# テスト用のヘルパーメソッド
func set_delayed_finish(delay: float):
  """遅延付きの完了をシミュレート"""
  if delay > 0.0:
    await get_tree().create_timer(delay).timeout
  _finish_dialogue()
