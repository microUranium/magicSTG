# WaveExecutorのテスト用モック
extends WaveExecutor
class_name MockWaveExecutor

# モック用の状態管理
var _mock_is_executing: bool = false
var _mock_is_paused: bool = false
var _mock_current_template: Dictionary = {}
var _mock_completed_layers: int = 0


func set_enemy_spawner(spawner: EnemySpawner) -> void:
  """EnemySpawner設定のモック（親クラスのメソッドをオーバーライド）"""
  super.set_enemy_spawner(spawner)


func execute_wave_template(template_data: Dictionary) -> bool:
  """ウェーブテンプレート実行のモック（親クラスのメソッドをオーバーライド）"""
  if _mock_is_executing:
    return false

  # null参照エラー防止
  if not template_data or not template_data.has("layers"):
    return false

  var layers = template_data.get("layers", [])
  if layers.is_empty():
    return false

  _mock_current_template = template_data
  _mock_is_executing = true
  _mock_completed_layers = 0

  # テスト用：即座に完了をシミュレート
  call_deferred("_simulate_completion")

  return true


func _simulate_completion():
  """完了のシミュレート（テスト用）"""
  if _mock_current_template.has("layers"):
    var layers = _mock_current_template["layers"]
    for i in range(layers.size()):
      layer_started.emit(i)
      layer_completed.emit(i)
      _mock_completed_layers += 1

  _mock_is_executing = false
  wave_completed.emit()


func stop_current_wave() -> void:
  """現在のウェーブ停止のモック（親クラスのメソッドをオーバーライド）"""
  _mock_is_executing = false
  _mock_current_template.clear()
  _mock_completed_layers = 0


func set_paused(paused: bool) -> void:
  """一時停止設定のモック（親クラスのメソッドをオーバーライド）"""
  _mock_is_paused = paused


func is_executing() -> bool:
  """実行中状態のモック（親クラスのメソッドをオーバーライド）"""
  return _mock_is_executing


func is_paused() -> bool:
  """一時停止状態のモック（親クラスのメソッドをオーバーライド）"""
  return _mock_is_paused


func get_current_layers() -> Array:
  """現在のレイヤー取得のモック（親クラスのメソッドをオーバーライド）"""
  if _mock_current_template.has("layers"):
    return _mock_current_template["layers"]
  return []


func get_completed_layers_count() -> int:
  """完了レイヤー数取得のモック（親クラスのメソッドをオーバーライド）"""
  return _mock_completed_layers


# テスト用のヘルパーメソッド
func simulate_wave_failure():
  """ウェーブ失敗をシミュレート"""
  _is_executing = false
  wave_failed.emit()


func simulate_layer_completion(layer_index: int):
  """レイヤー完了をシミュレート"""
  layer_completed.emit(layer_index)
  _completed_layers += 1
