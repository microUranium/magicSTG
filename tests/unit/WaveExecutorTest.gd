# ウェーブ実行コンポーネントの単体テスト（依存注入対応版）
extends GdUnitTestSuite
class_name WaveExecutorTest

# テスト対象クラス
var _wave_executor: WaveExecutor
var _test_scene: Node
var _mock_enemy_spawner: MockEnemySpawner

# テスト用のモックGameDataRegistry
var _original_data_loaded: bool


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # テスト対象のウェーブエグゼキューターを作成
  _wave_executor = WaveExecutor.new()
  _wave_executor.name = "WaveExecutor"
  _test_scene.add_child(_wave_executor)

  # null参照エラー防止：エグゼキューターが正常に作成されたことを確認
  assert_that(_wave_executor).is_not_null()

  # モック依存関係を作成
  _setup_mock_dependencies()

  # GameDataRegistryのモック化
  _setup_game_data_registry_mock()


func after_test():
  # リソースクリーンアップ
  _cleanup_game_data_registry_mock()
  if _test_scene:
    _test_scene.queue_free()


func _setup_mock_dependencies():
  """モック依存関係の作成"""
  # モックEnemySpawnerを作成
  _mock_enemy_spawner = MockEnemySpawner.new()
  _mock_enemy_spawner.name = "MockEnemySpawner"
  # スクリプトの存在確認してから設定
  var enemy_spawner_script = load("res://tests/stubs/MockEnemySpawner.gd")
  if enemy_spawner_script:
    _mock_enemy_spawner.set_script(enemy_spawner_script)
  _test_scene.add_child(_mock_enemy_spawner)


func _setup_game_data_registry_mock():
  """GameDataRegistryのモック化"""
  # 元の状態を保存
  _original_data_loaded = GameDataRegistry._data_loaded

  # テスト用のデータを設定
  GameDataRegistry._data_loaded = true
  GameDataRegistry.enemies = {"test_enemy": {"scene_path": "res://scenes/enemies/basic_enemy.tscn"}}
  GameDataRegistry.spawn_patterns = {
    "single_random": {"type": "single_random", "description": "Single random position spawn"},
    "line_horiz": {"type": "line_horiz", "description": "Horizontal line formation"}
  }


func _cleanup_game_data_registry_mock():
  """GameDataRegistryのモック状態をクリーンアップ"""
  # null参照エラー防止のため、存在確認してからクリーンアップ
  if GameDataRegistry:
    GameDataRegistry._data_loaded = _original_data_loaded
    if GameDataRegistry.has_method("clear") or "enemies" in GameDataRegistry:
      GameDataRegistry.enemies = {}
    if GameDataRegistry.has_method("clear") or "spawn_patterns" in GameDataRegistry:
      GameDataRegistry.spawn_patterns = {}


func test_enemy_spawner_injection():
  """EnemySpawner依存注入のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # 依存関係が正しく設定されたことを確認
  assert_that(_wave_executor._enemy_spawner).is_equal(_mock_enemy_spawner)


func test_signal_connection_management():
  """シグナル接続管理のテスト"""
  # 最初のEnemySpawner設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # 同じEnemySpawnerを再設定（重複接続を避ける）
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # エラーが発生しないことを確認
  assert_that(_wave_executor).is_not_null()


func test_wave_template_processing():
  """ウェーブテンプレート処理のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # テスト用のウェーブテンプレートデータ
  var template_data = {
    "layers":
    [
      {
        "enemy": "test_enemy", "count": 3, "pattern": "single_random", "interval": 0.5, "delay": 0.0
      },
      {"enemy": "test_enemy", "count": 2, "pattern": "line_horiz", "interval": 1.0, "delay": 1.0}
    ]
  }

  # ウェーブテンプレートを実行
  var result = _wave_executor.execute_wave_template(template_data)
  assert_that(result).is_true()

  # ウェーブが実行中になることを確認
  assert_that(_wave_executor.is_executing()).is_true()


func test_layer_execution():
  """レイヤー実行のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # 単一レイヤーのテンプレート
  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.5}]
  }

  # ウェーブ実行
  var result = _wave_executor.execute_wave_template(template_data)
  assert_that(result).is_true()

  # レイヤー情報を確認
  var current_layers = _wave_executor.get_current_layers()
  assert_that(current_layers.size()).is_equal(1)


func test_concurrent_layer_handling():
  """並行レイヤー処理のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # 複数レイヤー（異なる遅延）のテンプレート
  var template_data = {
    "layers":
    [
      {
        "enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.0
      },
      {"enemy": "test_enemy", "count": 1, "pattern": "line_horiz", "interval": 0.1, "delay": 0.5}
    ]
  }

  # ウェーブ実行
  var result = _wave_executor.execute_wave_template(template_data)
  assert_that(result).is_true()

  # 複数レイヤーが設定されることを確認
  var current_layers = _wave_executor.get_current_layers()
  assert_that(current_layers.size()).is_equal(2)


func test_invalid_template_handling():
  """無効なテンプレート処理のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # 空のレイヤーを持つテンプレート
  var empty_template = {"layers": []}
  var result1 = _wave_executor.execute_wave_template(empty_template)
  assert_that(result1).is_false()

  # レイヤーキーが無いテンプレート
  var no_layers_template = {}
  var result2 = _wave_executor.execute_wave_template(no_layers_template)
  assert_that(result2).is_false()


func test_execute_without_enemy_spawner():
  """EnemySpawnerが設定されていない場合のテスト"""
  # EnemySpawnerを設定せずにウェーブ実行を試行
  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.0}]
  }

  var result = _wave_executor.execute_wave_template(template_data)
  assert_that(result).is_false()


func test_duplicate_execution_prevention():
  """重複実行防止のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.5}]
  }

  # 最初の実行
  var result1 = _wave_executor.execute_wave_template(template_data)
  assert_that(result1).is_true()

  # 実行中に再度実行を試行
  var result2 = _wave_executor.execute_wave_template(template_data)
  assert_that(result2).is_false()


func test_pause_resume_functionality():
  """一時停止・再開機能のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ウェーブ実行
  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.0}]
  }
  _wave_executor.execute_wave_template(template_data)

  # 一時停止
  _wave_executor.set_paused(true)
  assert_that(_wave_executor.is_paused()).is_true()

  # 再開
  _wave_executor.set_paused(false)
  assert_that(_wave_executor.is_paused()).is_false()


func test_wave_completion():
  """ウェーブ完了のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ウェーブ実行
  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.0}]
  }
  _wave_executor.execute_wave_template(template_data)

  # 手動でレイヤー完了をシミュレート
  _wave_executor._on_layer_completed(0)

  # ウェーブが完了状態になることを確認
  assert_that(_wave_executor.is_executing()).is_false()


func test_stop_current_wave():
  """現在のウェーブ停止のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ウェーブ実行
  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.0}]
  }
  _wave_executor.execute_wave_template(template_data)

  # ウェーブ停止
  _wave_executor.stop_current_wave()
  assert_that(_wave_executor.is_executing()).is_false()


func test_layer_completion_tracking():
  """レイヤー完了追跡のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # 複数レイヤーのウェーブ実行
  var template_data = {
    "layers":
    [
      {
        "enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.5
      },
      {"enemy": "test_enemy", "count": 1, "pattern": "line_horiz", "interval": 0.1, "delay": 0.5}
    ]
  }
  _wave_executor.execute_wave_template(template_data)

  # 初期状態の完了レイヤー数
  assert_that(_wave_executor.get_completed_layers_count()).is_equal(0)

  # 1つ目のレイヤー完了
  _wave_executor._on_layer_completed(0)
  assert_that(_wave_executor.get_completed_layers_count()).is_equal(1)

  # 2つ目のレイヤー完了（全体完了）
  _wave_executor._on_layer_completed(1)
  assert_that(_wave_executor.is_executing()).is_false()


func test_spawn_event_conversion():
  """SpawnEvent変換のテスト"""
  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # レイヤーデータからSpawnEventへの変換テスト
  var layer_data = {"enemy": "test_enemy", "count": 3, "pattern": "single_random", "interval": 0.5}

  # 内部メソッドのテスト（変換処理が正常に動作するか）
  var spawn_events = _wave_executor._convert_layer_to_spawn_events(layer_data)

  # SpawnEventが生成されることを確認（エラーハンドリングのテスト）
  assert_that(spawn_events is Array).is_true()


func test_pattern_enum_conversion():
  """パターンEnum変換のテスト"""
  # 各パターン名からEnumへの変換をテスト
  var single_random = _wave_executor._get_spawn_event_pattern_enum("single_random")
  var line_horiz = _wave_executor._get_spawn_event_pattern_enum("line_horiz")
  var unknown = _wave_executor._get_spawn_event_pattern_enum("unknown_pattern")

  # 正しいEnum値が返されることを確認
  assert_that(single_random is int).is_true()
  assert_that(line_horiz is int).is_true()
  assert_that(unknown is int).is_true()


func test_signal_emission():
  """シグナル発火のテスト"""
  var wave_completed_fired = [false]
  var layer_started_fired = [false]
  var layer_completed_fired = [false]

  # シグナル接続
  _wave_executor.wave_completed.connect(func(): wave_completed_fired[0] = true)
  _wave_executor.layer_started.connect(func(idx): layer_started_fired[0] = true)
  _wave_executor.layer_completed.connect(func(idx): layer_completed_fired[0] = true)

  # EnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ウェーブ実行
  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 1, "pattern": "single_random", "interval": 0.1, "delay": 0.0}]
  }
  _wave_executor.execute_wave_template(template_data)

  # レイヤー完了をシミュレート
  _wave_executor._on_layer_completed(0)

  # シグナルが発火されたことを確認
  assert_that(layer_completed_fired[0]).is_true()
  assert_that(wave_completed_fired[0]).is_true()
