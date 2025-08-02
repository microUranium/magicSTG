extends Node
class_name StageManager

#---------------------------------------------------------------------
# Signals
#---------------------------------------------------------------------
signal segment_started(seg_idx)
signal wave_started(seg_idx)
signal wave_cleared(seg_idx)
signal stage_cleared

#---------------------------------------------------------------------
# Inspector
#---------------------------------------------------------------------
# 新システム用
@export var use_new_system: bool = false  # 新システムを使用するかどうか
@export var stage_seed: String = ""  # 新システム用シード値
@export_node_path("StageController") var stage_controller_path: NodePath
@export_node_path("WaveExecutor") var wave_executor_path: NodePath

# 旧システム用（互換性維持）
@export var segments: Array[StageSegment] = []  # 再生タイムライン
@export_node_path("Node") var spawner_path: NodePath  # EnemySpawner
@export_node_path("CanvasLayer") var dialogue_runner_path: NodePath
@export var inter_wave_delay := 2.0  # Wave → 次 Segment 待機
@export var ready_prompt_scene: PackedScene  # Optional "Ready?"
@export var start_segment_idx: int = 0  # 開始時のセグメントインデックス
@export var clear_prompt_scene: PackedScene = preload("res://scenes/ui/stageclear_prompt.tscn")
@export var gameover_prompt_scene: PackedScene = preload("res://scenes/ui/gameover_prompt.tscn")
@export var player_path: NodePath

# BGM
@export var stage_bgm: AudioStream
@export var stageclear_bgm: AudioStream
@export var bgm_fade_in := 2.0
@export var bgm_fade_out := 1.0

#---------------------------------------------------------------------
# Runtime
#---------------------------------------------------------------------
# 新システム用
var _stage_controller: StageController
var _wave_executor: WaveExecutor

# 旧システム用（互換性維持）
var _seg_idx := -1
@onready var _spawner: EnemySpawner = get_node(spawner_path) if spawner_path else null
@onready
var _drunner: DialogueRunner = get_node(dialogue_runner_path) if dialogue_runner_path else null

var _initialized := false
var _current_dialogue: DialogueData = null


#---------------------------------------------------------------------
# Life-cycle
#---------------------------------------------------------------------
func _ready() -> void:
  StageSignals.request_dialogue.connect(
    func(dd: DialogueData, finished_cb: Callable):
      _pause_attack_cores(true)
      _drunner.start_with_callback(dd, finished_cb)
  )

  if ready_prompt_scene:
    var prompt := ready_prompt_scene.instantiate()
    add_child(prompt)
    _pause_attack_cores(true)
    prompt.finished.connect(func(): _initialize_and_start())
  else:
    _initialize_and_start()


#---------------------------------------------------------------------
# Initialization
#---------------------------------------------------------------------
func _initialize_and_start() -> void:
  if _initialized:
    return
  _initialized = true

  # BulletLayerの初期化
  _setup_bullet_layer()

  if stage_bgm:
    StageSignals.emit_bgm_play_requested(stage_bgm, 0, -10)

  # 新システムか旧システムかで分岐
  if use_new_system:
    _initialize_new_system()
  else:
    _initialize_legacy_system()


#---------------------------------------------------------------------
# Segment Control
#---------------------------------------------------------------------
func _play_next_segment() -> void:
  _seg_idx += 1
  if _seg_idx >= segments.size():
    _pause_attack_cores(true)
    stage_cleared.emit()
    return

  var seg: StageSegment = segments[_seg_idx]
  segment_started.emit(_seg_idx)

  match seg.kind:
    StageSegment.Kind.WAVE:
      _pause_attack_cores(false)
      wave_started.emit(_seg_idx)
      _spawner.start_wave(seg.wave_data.spawn_events)
    StageSegment.Kind.DIALOGUE:
      _pause_attack_cores(true)
      _current_dialogue = seg.dialogue_data
      _drunner.start(seg.dialogue_data)
    _:
      push_warning("StageManager: Unknown segment kind %s" % seg.kind)
      _play_next_segment()  # スキップして次へ


#---------------------------------------------------------------------
# Callbacks
#---------------------------------------------------------------------
func _on_wave_finished() -> void:
  wave_cleared.emit(_seg_idx)
  await get_tree().create_timer(inter_wave_delay).timeout
  _play_next_segment()


func _on_dialogue_finished(_dd: DialogueData) -> void:
  _pause_attack_cores(false)
  if _current_dialogue == _dd:
    _play_next_segment()


func _on_stage_cleared() -> void:
  StageSignals.emit_bgm_stop_requested(bgm_fade_out)
  await get_tree().create_timer(2.0).timeout
  StageSignals.emit_bgm_play_requested(stageclear_bgm, 0.5, -10)
  if clear_prompt_scene:
    var prompt := clear_prompt_scene.instantiate()
    add_child(prompt)

  await get_tree().create_timer(5.0).timeout
  StageSignals.emit_bgm_stop_requested(bgm_fade_out)
  GameFlow.start_result_inventory()


func _on_game_over() -> void:
  print_debug("StageManager: Game Over")
  StageSignals.emit_bgm_stop_requested(bgm_fade_out)
  _pause_attack_cores(true)
  await get_tree().create_timer(2.0).timeout  # 少し待つ
  StageSignals.emit_signal("sfx_play_requested", "gameover", Vector2.INF, -10, 0)
  if gameover_prompt_scene:
    var prompt := gameover_prompt_scene.instantiate()
    add_child(prompt)

  await get_tree().create_timer(5.0).timeout
  GameFlow.start_result_inventory()


# -------------------------------------------------
# Helper : BulletLayer初期化
# -------------------------------------------------
func _setup_bullet_layer() -> void:
  """BulletLayerを見つけてTargetServiceに設定"""
  var bullet_layer = get_node_or_null("../BulletLayer")
  if bullet_layer:
    TargetService.set_bullet_parent(bullet_layer)
    print_debug("StageManager: BulletLayer initialized: %s" % bullet_layer.name)
  else:
    push_warning("StageManager: BulletLayer not found. Bullets will use fallback parent.")


# -------------------------------------------------
# 新システム初期化
# -------------------------------------------------
func _initialize_new_system() -> void:
  if stage_controller_path:
    _stage_controller = get_node(stage_controller_path)
  if wave_executor_path:
    _wave_executor = get_node(wave_executor_path)

  if not _stage_controller:
    push_error("StageManager: StageController not found, falling back to legacy system")
    _initialize_legacy_system()
    return

  # 新システムのシグナル接続
  _stage_controller.stage_completed.connect(_on_stage_cleared)
  _stage_controller.stage_failed.connect(_on_game_over)

  var player: Player = get_node_or_null(player_path)
  if player:
    player.game_over.connect(_on_game_over)

  # シード値でステージ開始
  if stage_seed.is_empty():
    stage_seed = "basic_swarm-Dstage1.intro-mixed_assault-boss_encounter-Dstage1.intro"  # デフォルト

  print_debug("StageManager: Starting new system with seed: %s" % stage_seed)
  # Readyプロンプト後に攻撃コアが停止されているため、ステージ開始時に適切に制御される
  _stage_controller.start_stage(stage_seed)


# -------------------------------------------------
# 旧システム初期化（互換性維持）
# -------------------------------------------------
func _initialize_legacy_system() -> void:
  if _spawner:
    _spawner.wave_finished.connect(_on_wave_finished)
  if _drunner:
    _drunner.dialogue_finished.connect(_on_dialogue_finished)

  stage_cleared.connect(_on_stage_cleared)

  var player: Player = get_node_or_null(player_path)
  if player:
    player.game_over.connect(_on_game_over)

  _seg_idx = start_segment_idx - 1
  _play_next_segment()


# -------------------------------------------------
# Helper : 攻撃核を一括停止 / 再開
# -------------------------------------------------
func _pause_attack_cores(paused: bool) -> void:
  for core in get_tree().get_nodes_in_group("attack_cores"):
    if core.has_method("set_paused"):
      core.set_paused(paused)
