# EnemySpawnerのテスト用モック
extends EnemySpawner
class_name MockEnemySpawner

# モック用の状態管理
var _mock_active_layers: Dictionary = {}  # layer_id -> bool
var _mock_layer_events: Dictionary = {}  # layer_id -> Array[SpawnEvent]


func start_layer(layer_id: String, events: Array) -> void:
  """レイヤー開始のモック"""
  # null参照エラー防止
  if not layer_id or layer_id.is_empty():
    push_warning("MockEnemySpawner: Invalid layer_id")
    return

  # eventsがnullまたは無効な場合は空配列に設定
  if not events or not events is Array:
    events = []

  _mock_active_layers[layer_id] = true
  _mock_layer_events[layer_id] = events

  # テスト用：即座にレイヤー完了をシミュレート
  call_deferred("_simulate_layer_completion", layer_id)


func _simulate_layer_completion(layer_id: String):
  """レイヤー完了のシミュレート"""
  if layer_id in _mock_active_layers:
    _mock_active_layers.erase(layer_id)
    _mock_layer_events.erase(layer_id)
    layer_finished.emit(layer_id)

    # 全てのレイヤーが完了した場合、ウェーブ完了をシミュレート
    if _mock_active_layers.is_empty():
      wave_finished.emit()


# モック用のユーティリティメソッド
func is_layer_active(layer_id: String) -> bool:
  """レイヤーがアクティブかチェック"""
  return layer_id in _mock_active_layers


func get_active_layer_count() -> int:
  """アクティブなレイヤー数を取得"""
  return _mock_active_layers.size()


func get_layer_events(layer_id: String) -> Array:
  """レイヤーのイベント取得"""
  return _mock_layer_events.get(layer_id, [])


func stop_all_layers():
  """全レイヤー停止のモック"""
  for layer_id in _mock_active_layers.keys():
    _mock_active_layers.erase(layer_id)
    _mock_layer_events.erase(layer_id)


# テスト用のヘルパーメソッド
func simulate_layer_failure(layer_id: String):
  """レイヤー失敗をシミュレート"""
  if layer_id in _mock_active_layers:
    _mock_active_layers.erase(layer_id)
    _mock_layer_events.erase(layer_id)
    # 失敗の場合は特別なシグナルは無いが、レイヤーは停止する


func simulate_wave_failure():
  """ウェーブ失敗をシミュレート"""
  stop_all_layers()
  # EnemySpawnerにはwave_failedシグナルが無いため、停止のみ


func force_layer_completion(layer_id: String):
  """強制的にレイヤー完了をシミュレート"""
  if layer_id in _mock_active_layers:
    _simulate_layer_completion(layer_id)
