extends EnemyPatternedAIBase
class_name BossBirdAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var attack_core_slot: UniversalAttackCoreSlot = null  # 攻撃コアをセットするスロット
@export var phase1_patterns: Array[AttackPattern]
@export var phase2_patterns: Array[AttackPattern]

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

var _phase_idx := 0
var _pattern_cores: Array[UniversalAttackCore] = []
var core_scene: PackedScene = preload("res://scenes/attackCores/universal_attack_core.tscn")


func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type

  _initialize_attack_patterns()

  super._ready()


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  if phase1_patterns.is_empty():
    phase1_patterns = create_phase1_pattern()
  if phase2_patterns.is_empty():
    phase2_patterns = create_phase2_pattern()


func _next_phase():
  if phases.is_empty():
    push_error("No phases defined in HarpyAI.")
    return

  _cancel_current_pattern()

  _phase_idx += 1
  if _phase_idx >= phases.size():
    return

  var phase := phases[_phase_idx]
  patterns = phase.patterns
  loop_type = phase.loop_type
  _idx = 0

  _setup_phase_attacks()

  if _phase_idx == 1 and not skip_bgm_change:
    StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size() and _phase_idx == 0:
    _next_phase()
  else:
    super._on_pattern_finished(cb_token)


func _setup_phase_attacks():
  """フェーズに応じた攻撃パターンを設定"""
  print_debug("Setting up phase attacks for phase index: ", _phase_idx)
  match _phase_idx:
    1:
      _set_attack_patterns(phase1_patterns)
    2:
      _clear_all_pattern_cores()  # Phase 2ではパターンをクリア


func _set_attack_patterns(patterns: Array[AttackPattern]):
  """攻撃パターンを汎用コアに設定"""
  var needed_cores = patterns.size()
  var current_cores = _pattern_cores.size()

  # 不要なコアを削除（逆順で削除）
  if current_cores > needed_cores:
    for i in range(current_cores - 1, needed_cores - 1, -1):
      if i < _pattern_cores.size():
        attack_core_slot.remove_core(_pattern_cores[i])
        _pattern_cores.remove_at(i)

  # 必要なコアを追加
  elif current_cores < needed_cores:
    for i in range(current_cores, needed_cores):
      var new_core = attack_core_slot.add_core(core_scene)
      _pattern_cores.append(new_core)

  # 各コアに独立したパターンを割り当て
  for i in range(patterns.size()):
    _pattern_cores[i].attack_pattern = patterns[i]
    _pattern_cores[i].cooldown_sec = patterns[i].burst_delay


func _clear_all_pattern_cores():
  """全てのパターンコアを削除"""
  for core in _pattern_cores:
    if is_instance_valid(core):
      attack_core_slot.remove_core(core)

  _pattern_cores.clear()


func create_phase1_pattern() -> Array[AttackPattern]:
  """Phase1相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(3):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 1, 3
    )
    pattern.target_group = "players"
    pattern.burst_delay = 5
    pattern.bullet_count = 12
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE

    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
    movement_config.initial_speed = 300.0 - (i * 30.0)
    movement_config.deceleration_rate = 200.0
    movement_config.min_speed = 150.0 - (i * 15.0)
    pattern.bullet_movement_config = movement_config
    patterns.append(pattern)

  return patterns


func create_phase2_pattern() -> Array[AttackPattern]:
  """Phase2相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(3):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 5, 0.7, 3
    )
    pattern.target_group = "players"
    pattern.burst_delay = 5
    pattern.bullet_count = 16
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE

    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
    movement_config.initial_speed = 300.0 - (i * 30.0)
    movement_config.deceleration_rate = 200.0
    movement_config.min_speed = 150.0 - (i * 15.0)
    pattern.bullet_movement_config = movement_config
    patterns.append(pattern)

  return patterns
