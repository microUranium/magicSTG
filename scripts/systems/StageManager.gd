extends Node
class_name StageManager

#---------------------------------------------------------------------
# Inspector
#---------------------------------------------------------------------
@export var stage_seed: String = ""  # 新システム用シード値
@export var player_path: NodePath
@export_node_path("StageController") var stage_controller_path: NodePath
@export_node_path("WaveExecutor") var wave_executor_path: NodePath
@export_node_path("CanvasLayer") var dialogue_runner_path: NodePath
@export_node_path("StageAudioController") var audio_controller_path: NodePath
@export_node_path("StageUIController") var ui_controller_path: NodePath
@export_node_path("StageEnvironmentSetup") var environment_setup_path: NodePath
@export_node_path("StageLifecycleController") var lifecycle_controller_path: NodePath
@export_node_path("PausePanelController") var pause_panel_path: NodePath

#---------------------------------------------------------------------
# Runtime
#---------------------------------------------------------------------
var _stage_controller: StageController
var _wave_executor: WaveExecutor
var _drunner: DialogueRunner

# Component Registry
var _component_registry: StageComponentRegistry

# Pause System
var _pause_panel: PausePanelController
var _is_stage_paused: bool = false


#---------------------------------------------------------------------
# Life-cycle
#---------------------------------------------------------------------
func _ready() -> void:
  # Component Registry初期化
  _setup_component_registry()

  # ダイアログシステム統合
  _setup_dialogue_integration()

  # ポーズシステム統合
  _setup_pause_system()

  # シード値準備（即座に実行）
  _prepare_stage_seed()

  # ステージ設定を即座に適用（背景とBGM設定）
  _apply_stage_config_immediately()

  # UIコントローラーからReady Prompt表示
  var ui_controller = _component_registry.get_component("ui")
  if ui_controller and ui_controller.has_ready_prompt():
    StageSignals.emit_signal("attack_cores_pause_requested", true)
    StageSignals.emit_signal("blessings_pause_requested", true)
    StageSignals.emit_signal("player_control_pause_requested", true)
    ui_controller.ready_prompt_finished.connect(_setup_stage_environment)
    ui_controller.show_ready_prompt()
  else:
    _setup_stage_environment()


#---------------------------------------------------------------------
# Initialization
#---------------------------------------------------------------------
func _apply_stage_config_immediately() -> void:
  """シーン読み込み時にステージ設定を即座に適用"""
  var current_stage = _determine_current_stage()
  var stage_config = GameDataRegistry.get_stage_config(current_stage)

  # 背景を即座に設定
  var environment_setup = _component_registry.get_component("environment")
  if environment_setup:
    environment_setup.setup_stage_background(stage_config)

  # BGM設定を準備（再生はしない）
  var audio_controller = _component_registry.get_component("audio")
  if audio_controller:
    audio_controller.set_stage_config(stage_config)


func _setup_stage_environment() -> void:
  var lifecycle_controller = _component_registry.get_component("lifecycle")
  if lifecycle_controller and lifecycle_controller.is_initialized():
    return

  # ライフサイクル初期化開始
  if lifecycle_controller:
    lifecycle_controller.start_initialization()

  # 環境セットアップ（背景設定は既に完了済み）
  var environment_setup = _component_registry.get_component("environment")
  if environment_setup:
    environment_setup.setup_stage_environment()

  # BGM開始（設定は既に完了済み）
  var audio_controller = _component_registry.get_component("audio")
  if audio_controller:
    audio_controller.handle_stage_start()

  # ライフサイクル初期化完了
  if lifecycle_controller:
    lifecycle_controller.complete_initialization()

  # ポーズ有効化（ステージ開始時）
  if _pause_panel:
    _pause_panel.enable_pause()

  _connect_stage_controller_and_start()


#---------------------------------------------------------------------
# Callbacks
#---------------------------------------------------------------------
func _on_stage_cleared() -> void:
  # ポーズ無効化
  if _pause_panel:
    _pause_panel.disable_pause()

  # ライフサイクル処理
  var lifecycle_controller = _component_registry.get_component("lifecycle")
  if lifecycle_controller:
    lifecycle_controller.handle_stage_cleared()

  # 音響処理
  var audio_controller = _component_registry.get_component("audio")
  if audio_controller:
    audio_controller.handle_stage_cleared()

  # UI処理
  var ui_controller = _component_registry.get_component("ui")
  if ui_controller:
    ui_controller.handle_stage_cleared()

  await get_tree().create_timer(7.0).timeout
  GameFlow.start_result_inventory()


func _on_game_over() -> void:
  # ポーズ無効化
  if _pause_panel:
    _pause_panel.disable_pause()

  StageSignals.emit_signal("attack_cores_pause_requested", true)
  StageSignals.emit_signal("blessings_pause_requested", true)
  StageSignals.emit_signal("player_control_pause_requested", true)

  # ライフサイクル処理
  var lifecycle_controller = _component_registry.get_component("lifecycle")
  if lifecycle_controller:
    lifecycle_controller.handle_stage_failed()

  # 即座にBGMを停止
  var audio_controller = _component_registry.get_component("audio")
  if audio_controller:
    audio_controller.stop_bgm()

  # 2秒待機
  await get_tree().create_timer(2.0).timeout

  # 音響処理（SFX再生）
  if audio_controller:
    audio_controller.handle_game_over()

  # UI処理
  var ui_controller = _component_registry.get_component("ui")
  if ui_controller:
    ui_controller.handle_game_over()

  await get_tree().create_timer(5.0).timeout
  GameFlow.start_result_inventory()


# -------------------------------------------------
# Component Registry Setup
# -------------------------------------------------
func _setup_component_registry() -> void:
  """Component Registryを設定し、全コンポーネントを初期化"""
  _component_registry = StageComponentRegistry.new()
  _component_registry.initialize(self)

  # コンポーネント登録（優先度順）
  _component_registry.register_component(
    "environment", environment_setup_path, StageEnvironmentSetup, 0
  )
  _component_registry.register_component("audio", audio_controller_path, StageAudioController, 1)
  _component_registry.register_component(
    "lifecycle", lifecycle_controller_path, StageLifecycleController, 2
  )
  _component_registry.register_component("ui", ui_controller_path, StageUIController, 3)

  # 依存関係設定
  _component_registry.add_dependency("audio", "environment")
  _component_registry.add_dependency("lifecycle", "environment")
  _component_registry.add_dependency("ui", "audio")

  # 全コンポーネント初期化
  if not _component_registry.initialize_all_components():
    push_error("StageManager: Component initialization failed")
    _component_registry.print_registry_status()

  # 旧システム（直接管理）
  if stage_controller_path:
    _stage_controller = get_node(stage_controller_path)
  if wave_executor_path:
    _wave_executor = get_node(wave_executor_path)
  if dialogue_runner_path:
    _drunner = get_node(dialogue_runner_path)


func _setup_dialogue_integration() -> void:
  """ダイアログシステムとの統合セットアップ"""
  if not _drunner:
    return

  StageSignals.request_dialogue.connect(_handle_dialogue_request)


func _handle_dialogue_request(dd: DialogueData, finished_cb: Callable) -> void:
  """ダイアログ要求の処理"""
  # ダイアログ中はポーズ無効化
  if _pause_panel:
    _pause_panel.disable_pause()

  StageSignals.emit_signal("attack_cores_pause_requested", true)
  StageSignals.emit_signal("blessings_pause_requested", true)
  StageSignals.emit_signal("player_control_pause_requested", true)

  # ダイアログ終了後にポーズ再有効化
  _drunner.start_with_callback(
    dd,
    func():
      finished_cb.call()
      # ステージ実行中のみポーズ再有効化
      var lifecycle_controller = _component_registry.get_component("lifecycle")
      if _pause_panel and lifecycle_controller and lifecycle_controller.is_stage_running():
        _pause_panel.enable_pause()
  )


# -------------------------------------------------
# StageController接続とステージ開始
# -------------------------------------------------
func _connect_stage_controller_and_start() -> void:
  if stage_controller_path:
    _stage_controller = get_node_or_null(stage_controller_path)
  if wave_executor_path:
    _wave_executor = get_node_or_null(wave_executor_path)

  if not _stage_controller:
    push_error("StageManager: StageController not found at path: %s" % stage_controller_path)
    return

  # WaveExecutorにEnemySpawnerを設定
  if _wave_executor:
    var enemy_spawner = get_node_or_null("../EnemySpawner")
    if enemy_spawner:
      _wave_executor.set_enemy_spawner(enemy_spawner)
    else:
      push_warning("StageManager: EnemySpawner not found for WaveExecutor")

  # StageControllerに依存関係を設定
  _stage_controller.set_dependencies(_wave_executor, _drunner)

  # 新システムのシグナル接続
  _stage_controller.stage_completed.connect(_on_stage_cleared)
  _stage_controller.stage_failed.connect(_on_game_over)

  var player: Player = get_node_or_null(player_path)
  if player:
    player.game_over.connect(_on_game_over)

  # Readyプロンプト後に攻撃コアが停止されているため、ステージ開始時に適切に制御される
  _stage_controller.start_stage(stage_seed)


func _determine_current_stage() -> String:
  """現在のステージを判定"""
  # シード値からステージを判定
  if stage_seed.contains("s4"):
    return "stage4"
  if stage_seed.contains("s3"):
    return "stage3"
  if stage_seed.contains("s2"):
    return "stage2"
  return "stage1"  # デフォルト


func _prepare_stage_seed() -> void:
  """ステージシード値の準備処理"""
  # 1. RandomSeedGeneratorからシード値取得を試行
  var generated_seed := RandomSeedGenerator.get_current_seed()
  if not generated_seed.is_empty():
    stage_seed = generated_seed
    print_debug("StageManager: Using generated seed from RandomSeedGenerator: '%s'" % stage_seed)
    return

  # 2. Inspector設定値がある場合はそれを使用
  if not stage_seed.is_empty():
    print_debug("StageManager: Using inspector-set seed: '%s'" % stage_seed)
    return

  # 3. デフォルト固定シード値
  stage_seed = "basic_swarm-Ds1d11.intro-mixed_assault-boss_encounter-Ds1d11.resolution"
  print_debug("StageManager: Using default seed: '%s'" % stage_seed)


#---------------------------------------------------------------------
# Lifecycle Event Handlers
#---------------------------------------------------------------------


func _handle_lifecycle_stage_cleared() -> void:
  """ライフサイクルコントローラーからのステージクリア通知"""
  print_debug("StageManager: Received lifecycle stage cleared signal")


func _handle_lifecycle_stage_failed() -> void:
  """ライフサイクルコントローラーからのステージ失敗通知"""
  print_debug("StageManager: Received lifecycle stage failed signal")


#---------------------------------------------------------------------
# Pause System
#---------------------------------------------------------------------


func _setup_pause_system() -> void:
  """ポーズシステムのセットアップ"""
  if not pause_panel_path:
    return

  _pause_panel = get_node_or_null(pause_panel_path)
  if _pause_panel:
    _pause_panel.pause_requested.connect(_handle_pause_requested)
    _pause_panel.resume_requested.connect(_handle_resume_requested)
    _pause_panel.quit_requested.connect(_handle_quit_requested)
    print_debug("StageManager: Pause system initialized")
  else:
    push_warning("StageManager: PausePanel not found at path: %s" % pause_panel_path)


func _handle_pause_requested() -> void:
  """ポーズ要求の処理"""
  var lifecycle_controller = _component_registry.get_component("lifecycle")
  if not lifecycle_controller or not lifecycle_controller.is_stage_running():
    return  # ステージ実行中のみポーズ可能

  # ライフサイクル状態更新
  lifecycle_controller.pause_stage()

  # ツリー全体をポーズ
  get_tree().paused = true
  _is_stage_paused = true

  # ポーズシグナル発行（既存システムとの互換性）
  StageSignals.emit_signal("attack_cores_pause_requested", true)
  StageSignals.emit_signal("blessings_pause_requested", true)
  StageSignals.emit_signal("player_control_pause_requested", true)

  # パネル表示
  if _pause_panel:
    _pause_panel.show_panel()

  print_debug("StageManager: Stage paused")


func _handle_resume_requested() -> void:
  """再開要求の処理"""
  if not _is_stage_paused:
    return

  # ツリーのポーズ解除
  get_tree().paused = false
  _is_stage_paused = false

  # ライフサイクル状態更新
  var lifecycle_controller = _component_registry.get_component("lifecycle")
  if lifecycle_controller:
    lifecycle_controller.resume_stage()

  # ポーズ解除シグナル発行（既存システムとの互換性）
  StageSignals.emit_signal("attack_cores_pause_requested", false)
  StageSignals.emit_signal("blessings_pause_requested", false)
  StageSignals.emit_signal("player_control_pause_requested", false)

  # パネル非表示
  if _pause_panel:
    _pause_panel.hide_panel()

  print_debug("StageManager: Stage resumed")


func _handle_quit_requested() -> void:
  """退出要求の処理"""
  # ポーズ解除（シーン遷移のため）
  if _is_stage_paused:
    get_tree().paused = false
    _is_stage_paused = false

  # ステージ失敗として扱う
  StageSignals.emit_signal("player_defeat_requested")
