# ステージコンポーネント統合テスト
extends GdUnitTestSuite
class_name StageComponentIntegrationTest

# テスト対象
var _stage_manager: StageManager
var _component_registry: StageComponentRegistry
var _test_scene: Node

# モックコンポーネント
var _mock_audio_controller: Node
var _mock_ui_controller: Node
var _mock_environment_setup: Node
var _mock_lifecycle_controller: Node


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # StageManagerを作成
  _stage_manager = StageManager.new()
  _stage_manager.name = "StageManager"
  _test_scene.add_child(_stage_manager)

  # null参照エラー防止：StageManagerが正常に作成されたことを確認
  assert_that(_stage_manager).is_not_null()

  # モックコンポーネントをセットアップ
  _setup_mock_components()


func after_test():
  # リソースクリーンアップ
  if _test_scene:
    _test_scene.queue_free()


func _setup_mock_components():
  """モックコンポーネントの作成"""
  # モックAudioController
  _mock_audio_controller = StageAudioController.new()
  _mock_audio_controller.name = "StageAudioController"
  _test_scene.add_child(_mock_audio_controller)

  # モックUIController
  _mock_ui_controller = StageUIController.new()
  _mock_ui_controller.name = "StageUIController"
  _test_scene.add_child(_mock_ui_controller)

  # モックEnvironmentSetup
  _mock_environment_setup = StageEnvironmentSetup.new()
  _mock_environment_setup.name = "StageEnvironmentSetup"
  _test_scene.add_child(_mock_environment_setup)

  # モックLifecycleController
  _mock_lifecycle_controller = StageLifecycleController.new()
  _mock_lifecycle_controller.name = "StageLifecycleController"
  _test_scene.add_child(_mock_lifecycle_controller)


func test_full_component_initialization():
  """完全なコンポーネント初期化のテスト"""
  # Component Registryを作成
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # null参照エラー防止
  assert_that(_component_registry).is_not_null()

  # コンポーネントを登録
  _component_registry.register_component(
    "environment", NodePath("../StageEnvironmentSetup"), StageEnvironmentSetup, 0
  )
  _component_registry.register_component(
    "audio", NodePath("../StageAudioController"), StageAudioController, 1
  )
  _component_registry.register_component(
    "lifecycle", NodePath("../StageLifecycleController"), StageLifecycleController, 2
  )
  _component_registry.register_component(
    "ui", NodePath("../StageUIController"), StageUIController, 3
  )

  # 依存関係を設定
  _component_registry.add_dependency("audio", "environment")
  _component_registry.add_dependency("lifecycle", "environment")
  _component_registry.add_dependency("ui", "audio")

  # 全コンポーネント初期化
  var result = _component_registry.initialize_all_components()
  assert_that(result).is_true()

  # 全コンポーネントが準備完了状態になることを確認
  assert_that(_component_registry.is_all_components_ready()).is_true()


func test_dependency_resolution_flow():
  """依存関係解決フローのテスト"""
  # Component Registryを作成
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # 依存関係のあるコンポーネントを登録（逆順で登録して解決順序をテスト）
  _component_registry.register_component(
    "ui", NodePath("../StageUIController"), StageUIController, 3
  )
  _component_registry.register_component(
    "audio", NodePath("../StageAudioController"), StageAudioController, 1
  )
  _component_registry.register_component(
    "environment", NodePath("../StageEnvironmentSetup"), StageEnvironmentSetup, 0
  )

  # 依存関係設定（UI -> Audio -> Environment）
  _component_registry.add_dependency("ui", "audio")
  _component_registry.add_dependency("audio", "environment")

  # 初期化実行
  var result = _component_registry.initialize_all_components()
  assert_that(result).is_true()

  # 依存関係が正しく解決されることを確認
  var environment_comp = _component_registry.get_component("environment")
  var audio_comp = _component_registry.get_component("audio")
  var ui_comp = _component_registry.get_component("ui")

  assert_that(environment_comp).is_not_null()
  assert_that(audio_comp).is_not_null()
  assert_that(ui_comp).is_not_null()


func test_component_communication():
  """コンポーネント間通信のテスト"""
  # Component Registryセットアップ
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # コンポーネント登録と初期化
  _component_registry.register_component(
    "audio", NodePath("../StageAudioController"), StageAudioController, 0
  )
  _component_registry.register_component(
    "ui", NodePath("../StageUIController"), StageUIController, 1
  )
  _component_registry.register_component(
    "lifecycle", NodePath("../StageLifecycleController"), StageLifecycleController, 2
  )

  var result = _component_registry.initialize_all_components()
  assert_that(result).is_true()

  # コンポーネント取得
  var audio_controller = _component_registry.get_component("audio")
  var ui_controller = _component_registry.get_component("ui")
  var lifecycle_controller = _component_registry.get_component("lifecycle")

  # コンポーネントが正常に取得できることを確認
  assert_that(audio_controller).is_not_null()
  assert_that(ui_controller).is_not_null()
  assert_that(lifecycle_controller).is_not_null()

  # コンポーネント間のメソッド呼び出しテスト
  audio_controller.handle_stage_start()
  ui_controller.handle_stage_cleared()
  lifecycle_controller.start_initialization()

  # エラーが発生しないことを確認
  assert_that(audio_controller).is_not_null()


func test_stage_lifecycle_integration():
  """ステージライフサイクル統合のテスト"""
  # Component Registryセットアップ
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # ライフサイクルに関連するコンポーネントを登録
  _component_registry.register_component(
    "environment", NodePath("../StageEnvironmentSetup"), StageEnvironmentSetup, 0
  )
  _component_registry.register_component(
    "audio", NodePath("../StageAudioController"), StageAudioController, 1
  )
  _component_registry.register_component(
    "lifecycle", NodePath("../StageLifecycleController"), StageLifecycleController, 2
  )
  _component_registry.register_component(
    "ui", NodePath("../StageUIController"), StageUIController, 3
  )

  # 依存関係設定
  _component_registry.add_dependency("audio", "environment")
  _component_registry.add_dependency("lifecycle", "environment")
  _component_registry.add_dependency("ui", "audio")

  # 初期化
  var result = _component_registry.initialize_all_components()
  assert_that(result).is_true()

  # ライフサイクルフローのテスト
  var lifecycle_controller = _component_registry.get_component("lifecycle")
  var audio_controller = _component_registry.get_component("audio")
  var ui_controller = _component_registry.get_component("ui")

  # 1. 初期化開始
  lifecycle_controller.start_initialization()
  assert_that(lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.INITIALIZING
  )

  # 2. 環境セットアップ
  var environment_setup = _component_registry.get_component("environment")
  environment_setup.setup_stage_environment()

  # 3. 音響開始
  audio_controller.handle_stage_start()

  # 4. 初期化完了
  lifecycle_controller.complete_initialization()
  assert_that(lifecycle_controller.is_stage_running()).is_true()

  # 5. ステージクリア処理
  lifecycle_controller.handle_stage_cleared()
  audio_controller.handle_stage_cleared()
  ui_controller.handle_stage_cleared()

  # エラーが発生しないことを確認
  assert_that(lifecycle_controller).is_not_null()


func test_error_propagation():
  """エラー伝播のテスト"""
  # Component Registryセットアップ
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  _component_registry.register_component(
    "working_component", NodePath("../StageAudioController"), StageAudioController, 0
  )
  # 存在しないNodePathを持つコンポーネントを登録
  _component_registry.register_component(
    "failing_component", NodePath("NonExistentNode"), StageAudioController, 1
  )

  # 初期化実行（失敗するはず）
  var result = _component_registry.initialize_all_components()
  assert_that(result).is_false()

  # 失敗したコンポーネントがリストに含まれることを確認
  var failed_components = _component_registry.get_failed_components()
  assert_that(failed_components.size()).is_greater(0)
  assert_that("failing_component" in failed_components).is_true()

  # 成功したコンポーネントは取得可能であることを確認
  var working_component = _component_registry.get_component("working_component")
  assert_that(working_component).is_not_null()


func test_partial_component_failure():
  """部分的なコンポーネント失敗のテスト"""
  # Component Registryセットアップ
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # 正常なコンポーネントと失敗するコンポーネントを混在
  _component_registry.register_component(
    "audio", NodePath("../StageAudioController"), StageAudioController, 0
  )
  _component_registry.register_component(
    "invalid", NodePath("../NonExistentNode"), StageAudioController, 1
  )
  _component_registry.register_component(
    "ui", NodePath("../StageUIController"), StageUIController, 2
  )

  # 初期化実行
  var result = _component_registry.initialize_all_components()
  assert_that(result).is_false()

  # 成功したコンポーネントは利用可能
  assert_that(_component_registry.get_component("audio")).is_not_null()

  # 失敗したコンポーネントと後続のコンポーネントはnull
  assert_that(_component_registry.get_component("invalid")).is_null()
  assert_that(_component_registry.get_component("ui")).is_null()

  # 全体の準備完了状態はfalse
  assert_that(_component_registry.is_all_components_ready()).is_false()


var _signal_received := false


func test_signal_propagation():
  """シグナル伝播のテスト"""
  # Component Registryセットアップ
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # ライフサイクルコントローラーを登録
  _component_registry.register_component(
    "lifecycle", NodePath("../StageLifecycleController"), StageLifecycleController, 0
  )

  var result = _component_registry.initialize_all_components()
  assert_that(result).is_true()

  # シグナル発火のテスト
  _signal_received = false
  var lifecycle_controller = _component_registry.get_component("lifecycle")

  lifecycle_controller.stage_initialization_started.connect(func(): _signal_received = true)

  # シグナル発火
  lifecycle_controller.start_initialization()

  # シグナルが受信されることを確認
  assert_that(_signal_received).is_true()


func test_multiple_initialization_attempts():
  """複数回初期化試行のテスト"""
  # Component Registryセットアップ
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # コンポーネント登録
  _component_registry.register_component(
    "audio", NodePath("../StageAudioController"), StageAudioController, 0
  )

  # 最初の初期化
  var result1 = _component_registry.initialize_all_components()
  assert_that(result1).is_true()

  # 2回目の初期化（既に初期化済みのため、安全に処理される）
  var result2 = _component_registry.initialize_all_components()
  assert_that(result2).is_true()

  # コンポーネントが正常に動作することを確認
  var audio_controller = _component_registry.get_component("audio")
  assert_that(audio_controller).is_not_null()


func test_complex_dependency_chain():
  """複雑な依存関係チェーンのテスト"""
  # Component Registryセットアップ
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(_stage_manager)

  # 複雑な依存関係を持つコンポーネントを登録
  _component_registry.register_component(
    "env", NodePath("../StageEnvironmentSetup"), StageEnvironmentSetup, 0
  )
  _component_registry.register_component(
    "audio", NodePath("../StageAudioController"), StageAudioController, 1
  )
  _component_registry.register_component(
    "lifecycle", NodePath("../StageLifecycleController"), StageLifecycleController, 2
  )
  _component_registry.register_component(
    "ui", NodePath("../StageUIController"), StageUIController, 3
  )

  # 複雑な依存関係設定
  # env <- audio, lifecycle
  # audio <- ui
  _component_registry.add_dependency("audio", "env")
  _component_registry.add_dependency("lifecycle", "env")
  _component_registry.add_dependency("ui", "audio")

  # 初期化実行
  var result = _component_registry.initialize_all_components()
  assert_that(result).is_true()

  # 全てのコンポーネントが正常に初期化されることを確認
  assert_that(_component_registry.get_component("env")).is_not_null()
  assert_that(_component_registry.get_component("audio")).is_not_null()
  assert_that(_component_registry.get_component("lifecycle")).is_not_null()
  assert_that(_component_registry.get_component("ui")).is_not_null()
