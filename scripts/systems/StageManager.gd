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
var _seg_idx := -1
@onready var _spawner: EnemySpawner = get_node(spawner_path)
@onready var _drunner: DialogueRunner = get_node(dialogue_runner_path)

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

  if stage_bgm:
    StageSignals.emit_bgm_play_requested(stage_bgm, 0, -10)

  _spawner.wave_finished.connect(_on_wave_finished)
  _drunner.dialogue_finished.connect(_on_dialogue_finished)
  stage_cleared.connect(_on_stage_cleared)

  var player: Player = get_node_or_null(player_path)
  if player:
    player.game_over.connect(_on_game_over)

  _seg_idx = start_segment_idx - 1
  _play_next_segment()


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
  GameFlow.change_to_title()


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
  GameFlow.change_to_title()


# -------------------------------------------------
# Helper : 攻撃核を一括停止 / 再開
# -------------------------------------------------
func _pause_attack_cores(paused: bool) -> void:
  for core in get_tree().get_nodes_in_group("attack_cores"):
    if core.has_method("set_paused"):
      core.set_paused(paused)
