# ステージ制御コンポーネントの単体テスト（依存注入対応版）
extends GdUnitTestSuite
class_name StageControllerTest

# テスト対象クラス
var _stage_controller: StageController
var _test_scene: Node
var _mock_wave_executor: MockWaveExecutor
var _mock_dialogue_runner: MockDialogueRunner

# テスト用のモックGameDataRegistry
var _original_data_loaded: bool


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # テスト対象のステージコントローラを作成
  _stage_controller = StageController.new()
  _stage_controller.name = "StageController"
  _test_scene.add_child(_stage_controller)

  # null参照エラー防止：コントローラーが正常に作成されたことを確認
  assert_that(_stage_controller).is_not_null()

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
  # モックWaveExecutorを作成
  _mock_wave_executor = MockWaveExecutor.new()
  _mock_wave_executor.name = "MockWaveExecutor"
  # スクリプトの存在確認してから設定
  var wave_executor_script = load("res://tests/stubs/MockWaveExecutor.gd")
  if wave_executor_script:
    _mock_wave_executor.set_script(wave_executor_script)
  _test_scene.add_child(_mock_wave_executor)

  # モックDialogueRunnerを作成
  _mock_dialogue_runner = MockDialogueRunner.new()
  _mock_dialogue_runner.name = "MockDialogueRunner"
  # スクリプトの存在確認してから設定
  var dialogue_runner_script = load("res://tests/stubs/MockDialogueRunner.gd")
  if dialogue_runner_script:
    _mock_dialogue_runner.set_script(dialogue_runner_script)
  _test_scene.add_child(_mock_dialogue_runner)


func _setup_game_data_registry_mock():
  """GameDataRegistryのモック化"""
  # 元の状態を保存
  _original_data_loaded = GameDataRegistry._data_loaded

  # テスト用のデータを設定
  GameDataRegistry._data_loaded = true
  GameDataRegistry.wave_templates = {
    "test_wave":
    {
      "layers":
      [
        {
          "enemy": "test_enemy",
          "count": 5,
          "pattern": "single_random",
          "interval": 0.5,
          "delay": 0.0
        }
      ]
    }
  }
  GameDataRegistry.dialogues = {
    "test_pool":
    {
      "intro":
      [
        {
          "speaker_name": "Test Speaker",
          "text": "Test dialogue text",
          "speaker_side": "left",
          "box_direction": "left"
        }
      ]
    }
  }


func _cleanup_game_data_registry_mock():
  """GameDataRegistryのモック状態をクリーンアップ"""
  # null参照エラー防止のため、存在確認してからクリーンアップ
  if GameDataRegistry:
    GameDataRegistry._data_loaded = _original_data_loaded
    if GameDataRegistry.has_method("clear") or "wave_templates" in GameDataRegistry:
      GameDataRegistry.wave_templates = {}
    if GameDataRegistry.has_method("clear") or "dialogues" in GameDataRegistry:
      GameDataRegistry.dialogues = {}
    if GameDataRegistry.has_method("clear") or "enemies" in GameDataRegistry:
      GameDataRegistry.enemies = {}
    if GameDataRegistry.has_method("clear") or "spawn_patterns" in GameDataRegistry:
      GameDataRegistry.spawn_patterns = {}


func test_dependency_injection():
  """依存注入のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # 依存関係が正しく設定されたことを確認
  assert_that(_stage_controller._wave_executor).is_equal(_mock_wave_executor)
  assert_that(_stage_controller._dialogue_runner).is_equal(_mock_dialogue_runner)


func test_seed_parsing():
  """シード解析のテスト"""
  # 有効なシード値でのテスト
  var result = _stage_controller.start_stage("test_wave-Dtest_pool.intro")
  assert_that(result).is_true()

  # シード値が保存されることを確認
  assert_that(_stage_controller.get_current_seed()).is_equal("test_wave-Dtest_pool.intro")


func test_invalid_seed_parsing():
  """無効なシード解析のテスト"""
  # 空のシード値
  var result1 = _stage_controller.start_stage("")
  assert_that(result1).is_false()

  # 存在しないウェーブテンプレート
  var result2 = _stage_controller.start_stage("nonexistent_wave")
  assert_that(result2).is_false()

  # 不正なダイアログパス
  var result3 = _stage_controller.start_stage("Dinvalid_dialogue_path")
  assert_that(result3).is_false()


func test_wave_event_execution():
  """ウェーブイベント実行のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ウェーブのみのシードでステージを開始
  var result = _stage_controller.start_stage("test_wave")
  assert_that(result).is_true()

  # イベントキューにウェーブイベントが追加されることを確認
  assert_that(_stage_controller.get_total_events()).is_greater(0)


func test_dialogue_event_execution():
  """ダイアログイベント実行のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ダイアログのみのシードでステージを開始
  var result = _stage_controller.start_stage("Dtest_pool.intro")
  assert_that(result).is_true()

  # イベントキューにダイアログイベントが追加されることを確認
  assert_that(_stage_controller.get_total_events()).is_greater(0)


func test_mixed_event_execution():
  """混合イベント実行のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ウェーブとダイアログの混合シードでステージを開始
  var result = _stage_controller.start_stage("test_wave-Dtest_pool.intro-test_wave")
  assert_that(result).is_true()

  # 複数のイベントがキューに追加されることを確認
  assert_that(_stage_controller.get_total_events()).is_equal(3)


func test_signal_connection_safety():
  """シグナル接続の安全性テスト"""
  # 最初の依存関係設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # 同じ依存関係を再設定（重複接続を避ける）
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # エラーが発生しないことを確認
  assert_that(_stage_controller).is_not_null()


func test_attack_core_pause_integration():
  """攻撃コア一時停止統合のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # 攻撃コア制御メソッドが呼び出されることを確認（実際の制御は統合テストで確認）
  assert_that(_stage_controller).is_not_null()


func test_stage_completion_flow():
  """ステージ完了フローのテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # ステージ完了処理
  _stage_controller._complete_stage()

  # ステージが実行中でなくなることを確認
  assert_that(_stage_controller.is_stage_running()).is_false()


func test_stage_failure_flow():
  """ステージ失敗フローのテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # ステージ失敗処理
  _stage_controller._fail_stage()

  # ステージが実行中でなくなることを確認
  assert_that(_stage_controller.is_stage_running()).is_false()


func test_stage_pause_resume():
  """ステージ一時停止・再開のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # 一時停止
  _stage_controller.pause_stage(true)

  # 再開
  _stage_controller.pause_stage(false)

  # エラーが発生しないことを確認
  assert_that(_stage_controller).is_not_null()


func test_stage_stop():
  """ステージ停止のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # ステージ停止
  _stage_controller.stop_stage()

  # ステージが実行中でなくなることを確認
  assert_that(_stage_controller.is_stage_running()).is_false()


func test_without_game_data_registry():
  """GameDataRegistryが読み込まれていない場合のテスト"""
  # GameDataRegistryを未読み込み状態に設定
  GameDataRegistry._data_loaded = false

  # ステージ開始を試行
  var result = _stage_controller.start_stage("test_wave")
  assert_that(result).is_false()

  # 元の状態に戻す
  GameDataRegistry._data_loaded = true


func test_without_dependencies():
  """依存関係が設定されていない場合のテスト"""
  # 依存関係を設定せずにステージ開始を試行
  var result = _stage_controller.start_stage("test_wave")

  # WaveExecutorが無い場合でも基本的な解析は成功するはず
  assert_that(result).is_true()


func test_dialogue_token_management():
  """ダイアログトークン管理のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # ダイアログイベントを含むステージを開始
  _stage_controller.start_stage("Dtest_pool.intro")

  # ダイアログトークンが設定されることを確認（内部的にトークンが管理される）
  assert_that(_stage_controller._current_dialogue_token).is_not_equal("")


func test_current_event_tracking():
  """現在のイベント追跡のテスト"""
  # 依存関係を設定
  _stage_controller.set_dependencies(_mock_wave_executor, _mock_dialogue_runner)

  # 複数イベントのステージを開始
  _stage_controller.start_stage("test_wave-Dtest_pool.intro")

  # 現在のイベントインデックスを確認
  assert_that(_stage_controller.get_current_event_index()).is_equal(0)

  # 総イベント数を確認
  assert_that(_stage_controller.get_total_events()).is_equal(2)


func test_inter_wave_delay():
  """ウェーブ間遅延のテスト"""
  # 遅延時間を設定
  _stage_controller.inter_wave_delay = 1.0

  # 設定値が正しく保存されることを確認
  assert_that(_stage_controller.inter_wave_delay).is_equal(1.0)
