# ステージマネージャー統合テスト
extends GdUnitTestSuite
class_name StageManagerIntegrationTest

# テスト対象
var _stage_manager: StageManager
var _stage_controller: StageController
var _wave_executor: WaveExecutor
var _dialogue_runner: DialogueRunner
var _test_scene: Node

# モックコンポーネント
var _mock_audio_controller: StageAudioController
var _mock_ui_controller: StageUIController
var _mock_environment_setup: StageEnvironmentSetup
var _mock_lifecycle_controller: StageLifecycleController
var _mock_enemy_spawner: Node

# テスト用のGameDataRegistry状態
var _original_data_loaded: bool

# シグナル受信フラグ
var stage_completed_received = false
var wave_completed_received = false


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # メインコンポーネントの作成
  _setup_main_components()

  # モックコンポーネントの作成
  _setup_mock_components()

  # GameDataRegistryのモック化
  _setup_game_data_registry_mock()


func after_test():
  # リソースクリーンアップ
  _cleanup_game_data_registry_mock()
  if _test_scene:
    _test_scene.queue_free()


func _setup_main_components():
  """メインコンポーネントの作成"""
  # StageManagerを作成
  _stage_manager = StageManager.new()
  _stage_manager.name = "StageManager"
  _test_scene.add_child(_stage_manager)

  # StageControllerを作成
  _stage_controller = StageController.new()
  _stage_controller.name = "StageController"
  _test_scene.add_child(_stage_controller)

  # WaveExecutorを作成
  _wave_executor = WaveExecutor.new()
  _wave_executor.name = "WaveExecutor"
  _test_scene.add_child(_wave_executor)

  # DialogueRunnerを作成
  _dialogue_runner = DialogueRunner.new()
  _dialogue_runner.name = "DialogueRunner"
  _test_scene.add_child(_dialogue_runner)

  # null参照エラー防止
  assert_that(_stage_manager).is_not_null()
  assert_that(_stage_controller).is_not_null()
  assert_that(_wave_executor).is_not_null()
  assert_that(_dialogue_runner).is_not_null()


func _setup_mock_components():
  """モックコンポーネントの作成"""
  # モックEnemySpawner
  _mock_enemy_spawner = Node.new()
  _mock_enemy_spawner.name = "EnemySpawner"
  # スクリプトの存在確認してから設定
  var enemy_spawner_script = load("res://tests/stubs/MockEnemySpawner.gd")
  if enemy_spawner_script:
    _mock_enemy_spawner.set_script(enemy_spawner_script)
  _test_scene.add_child(_mock_enemy_spawner)

  # StageManager配下のモックコンポーネント
  _mock_audio_controller = StageAudioController.new()
  _mock_audio_controller.name = "StageAudioController"
  _stage_manager.add_child(_mock_audio_controller)

  _mock_ui_controller = StageUIController.new()
  _mock_ui_controller.name = "StageUIController"
  _stage_manager.add_child(_mock_ui_controller)

  _mock_environment_setup = StageEnvironmentSetup.new()
  _mock_environment_setup.name = "StageEnvironmentSetup"
  _stage_manager.add_child(_mock_environment_setup)

  _mock_lifecycle_controller = StageLifecycleController.new()
  _mock_lifecycle_controller.name = "StageLifecycleController"
  _stage_manager.add_child(_mock_lifecycle_controller)


func _setup_game_data_registry_mock():
  """GameDataRegistryのモック化"""
  _original_data_loaded = GameDataRegistry._data_loaded

  GameDataRegistry._data_loaded = true
  GameDataRegistry.wave_templates = {
    "test_wave":
    {
      "layers":
      [
        {
          "enemy": "test_enemy",
          "count": 3,
          "pattern": "single_random",
          "interval": 0.5,
          "delay": 0.0
        }
      ]
    },
    "complex_wave":
    {
      "layers":
      [
        {"enemy": "test_enemy", "count": 2, "pattern": "line_horiz", "interval": 0.3, "delay": 0.0},
        {
          "enemy": "test_enemy",
          "count": 1,
          "pattern": "single_random",
          "interval": 0.5,
          "delay": 1.0
        }
      ]
    }
  }
  GameDataRegistry.dialogues = {
    "stage1":
    {
      "intro":
      [
        {
          "speaker_name": "Narrator",
          "text": "Stage begins!",
          "speaker_side": "left",
          "box_direction": "left"
        }
      ],
      "outro":
      [
        {
          "speaker_name": "Narrator",
          "text": "Stage cleared!",
          "speaker_side": "right",
          "box_direction": "right"
        }
      ]
    }
  }
  GameDataRegistry.enemies = {"test_enemy": {"scene_path": "res://scenes/enemies/basic_enemy.tscn"}}
  GameDataRegistry.spawn_patterns = {
    "single_random": {"type": "single_random"}, "line_horiz": {"type": "line_horiz"}
  }


func _cleanup_game_data_registry_mock():
  """GameDataRegistryのクリーンアップ"""
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


func test_complete_stage_execution():
  """完全なステージ実行のテスト"""
  # StageManagerのコンポーネントパス設定
  _stage_manager.stage_controller_path = NodePath("../StageController")
  _stage_manager.wave_executor_path = NodePath("../WaveExecutor")
  _stage_manager.dialogue_runner_path = NodePath("../DialogueRunner")
  _stage_manager.audio_controller_path = NodePath("StageAudioController")
  _stage_manager.ui_controller_path = NodePath("StageUIController")
  _stage_manager.environment_setup_path = NodePath("StageEnvironmentSetup")
  _stage_manager.lifecycle_controller_path = NodePath("StageLifecycleController")

  # StageManagerの手動初期化（_setup_component_registryを模擬）
  _stage_manager._component_registry = StageComponentRegistry.new()
  _stage_manager._component_registry.initialize(_stage_manager)

  # 依存関係の設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # シンプルなウェーブでステージ実行
  var result = _stage_controller.start_stage("test_wave")
  assert_that(result).is_true()

  # ステージが実行中になることを確認
  assert_that(_stage_controller.is_stage_running()).is_true()


func test_ready_prompt_to_stage_start():
  """ReadyPrompt→ステージ開始のフローテスト"""
  # StageManagerのコンポーネントパス設定
  _stage_manager.stage_controller_path = NodePath("../StageController")
  _stage_manager.wave_executor_path = NodePath("../WaveExecutor")
  _stage_manager.ui_controller_path = NodePath("StageUIController")
  _stage_manager.environment_setup_path = NodePath("StageEnvironmentSetup")
  _stage_manager.lifecycle_controller_path = NodePath("StageLifecycleController")

  # UIコントローラーのReady prompt設定（nullでテスト）
  _mock_ui_controller.ready_prompt_scene = null

  # 依存関係設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ライフサイクルコントローラーの初期化
  _mock_lifecycle_controller.start_initialization()

  # 環境セットアップ
  _mock_environment_setup.setup_stage_environment()

  # 音響コントローラーでステージ開始
  _mock_audio_controller.handle_stage_start()

  # ライフサイクル完了
  _mock_lifecycle_controller.complete_initialization()

  # ステージ開始
  var result = _stage_controller.start_stage("test_wave")
  assert_that(result).is_true()


func test_game_over_flow():
  """ゲームオーバーフローのテスト"""
  # コンポーネント設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # ライフサイクルコントローラーでゲームオーバー処理
  _mock_lifecycle_controller.start_initialization()
  _mock_lifecycle_controller.complete_initialization()
  _mock_lifecycle_controller.handle_stage_failed()

  # 音響コントローラーでゲームオーバー処理
  _mock_audio_controller.handle_game_over()

  # UIコントローラーでゲームオーバー処理
  _mock_ui_controller.handle_game_over()

  # エラーが発生しないことを確認
  assert_that(_stage_controller).is_not_null()


func test_stage_clear_flow():
  """ステージクリアフローのテスト"""
  # コンポーネント設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # ライフサイクルでステージクリア処理
  _mock_lifecycle_controller.start_initialization()
  _mock_lifecycle_controller.complete_initialization()
  _mock_lifecycle_controller.handle_stage_cleared()

  # 音響コントローラーでクリア処理
  _mock_audio_controller.handle_stage_cleared()

  # UIコントローラーでクリア処理
  _mock_ui_controller.handle_stage_cleared()

  # エラーが発生しないことを確認
  assert_that(_stage_controller).is_not_null()


func test_dialogue_integration():
  """ダイアログ統合のテスト"""
  # コンポーネント設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)

  # ダイアログを含むステージ実行
  var result = _stage_controller.start_stage("Dstage1.intro-test_wave-Dstage1.outro")
  assert_that(result).is_true()

  # 複数のイベントがキューに追加されることを確認
  assert_that(_stage_controller.get_total_events()).is_equal(3)


func test_mixed_event_sequence():
  """混合イベントシーケンスのテスト"""
  # コンポーネント設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # 複雑なシーケンスでステージ実行
  var result = _stage_controller.start_stage("Dstage1.intro-test_wave-complex_wave-Dstage1.outro")
  assert_that(result).is_true()

  # 4つのイベントがキューに追加されることを確認
  assert_that(_stage_controller.get_total_events()).is_equal(4)

  # ステージが正常に開始されることを確認
  assert_that(_stage_controller.is_stage_running()).is_true()


func test_wave_executor_integration():
  """WaveExecutor統合のテスト"""
  # WaveExecutorにEnemySpawnerを設定
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # テンプレートデータで直接実行
  var template_data = {
    "layers":
    [{"enemy": "test_enemy", "count": 2, "pattern": "single_random", "interval": 0.3, "delay": 0.5}]
  }

  var result = _wave_executor.execute_wave_template(template_data)
  assert_that(result).is_true()

  # ウェーブが実行中になることを確認
  assert_that(_wave_executor.is_executing()).is_true()


func test_component_signal_chain():
  """コンポーネントシグナルチェーンのテスト"""
  stage_completed_received = false
  wave_completed_received = false

  # シグナル接続
  _stage_controller.stage_completed.connect(_on_stage_completed)
  _wave_executor.wave_completed.connect(_on_wave_completed)

  # コンポーネント設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ステージ実行
  _stage_controller.start_stage("test_wave")

  # ウェーブ完了をシミュレート
  _wave_executor._complete_wave()

  # シグナルが発火されることを確認
  assert_that(wave_completed_received).is_true()


func test_error_handling_integration():
  """エラーハンドリング統合のテスト"""
  # 無効な設定でのテスト
  _stage_controller.set_dependencies(null, null)

  # 無効なシードでの実行試行
  var result = _stage_controller.start_stage("invalid_seed")
  assert_that(result).is_false()

  # 正常な設定に戻して再試行
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  var valid_result = _stage_controller.start_stage("test_wave")
  assert_that(valid_result).is_true()


func test_pause_resume_integration():
  """一時停止・再開統合のテスト"""
  # コンポーネント設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")

  # 一時停止
  _stage_controller.pause_stage(true)
  assert_that(_wave_executor.is_paused()).is_true()

  # 再開
  _stage_controller.pause_stage(false)
  assert_that(_wave_executor.is_paused()).is_false()


func test_stage_stop_integration():
  """ステージ停止統合のテスト"""
  # コンポーネント設定
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)

  # ステージ開始
  _stage_controller.start_stage("test_wave")
  assert_that(_stage_controller.is_stage_running()).is_true()

  # ステージ停止
  _stage_controller.stop_stage()
  assert_that(_stage_controller.is_stage_running()).is_false()
  assert_that(_wave_executor.is_executing()).is_false()


func test_component_lifecycle_coordination():
  """コンポーネントライフサイクル協調のテスト"""
  # 全コンポーネントでライフサイクル開始
  _mock_lifecycle_controller.start_initialization()
  assert_that(_mock_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.INITIALIZING
  )

  # 環境セットアップ
  _mock_environment_setup.setup_stage_environment()

  # 音響開始
  _mock_audio_controller.handle_stage_start()

  # ライフサイクル完了
  _mock_lifecycle_controller.complete_initialization()
  assert_that(_mock_lifecycle_controller.is_stage_running()).is_true()

  # ステージ制御開始
  _stage_controller.set_dependencies(_wave_executor, _dialogue_runner)
  _wave_executor.set_enemy_spawner(_mock_enemy_spawner)
  var result = _stage_controller.start_stage("test_wave")
  assert_that(result).is_true()

  # 全体的な協調動作が正常であることを確認
  assert_that(_stage_controller.is_stage_running()).is_true()
  assert_that(_mock_lifecycle_controller.is_stage_running()).is_true()


# ヘルパー関数
func _on_stage_completed():
  stage_completed_received = true


func _on_wave_completed():
  wave_completed_received = true
