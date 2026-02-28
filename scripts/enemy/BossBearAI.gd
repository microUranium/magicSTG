extends EnemyPatternedAIBase
class_name BossBearAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns: Array[AttackPattern]
@export var phase2_patterns: Array[AttackPattern]

@export var visual_config: BulletVisualConfig = null  # ビジュアル設定

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

var _phase_idx := 0
var _phase_transition_counter := 0

var _bgm_played := false
var _phase_changable := false  # 第2形態に移行可能かどうか


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
    _phase_idx -= 2  # 最終フェーズに到達したら前のフェーズに戻る

  var phase := phases[_phase_idx]
  patterns = phase.patterns
  loop_type = phase.loop_type
  _idx = 0

  _setup_phase_attacks()

  if _phase_idx == 1 and not skip_bgm_change and not _bgm_played:
    StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト
    _bgm_played = true

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size():
    if _phase_idx == 0 or _phase_idx == 2:
      _next_phase()
    elif _phase_idx == 1:
      _phase_transition_counter += 1
      if _phase_transition_counter >= 20 and _phase_changable:
        _phase_transition_counter = 0
        _next_phase()
      else:
        super._on_pattern_finished(cb_token)
  else:
    super._on_pattern_finished(cb_token)


func _next_pattern():
  super._next_pattern()


func _setup_phase_attacks():
  """フェーズに応じた攻撃パターンを設定"""
  print_debug("Setting up phase attacks for phase index: ", _phase_idx)
  match _phase_idx:
    1:
      _clear_all_pattern_cores()
      _set_attack_patterns(phase1_patterns)
    2:
      _clear_all_pattern_cores()
      _set_attack_patterns(phase2_patterns)


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

  for i in range(5):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 5, 0.3, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 1.5
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE
    pattern.bullet_count = 12
    pattern.bullet_speed = 300 - i * -40

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    patterns.append(pattern)

  var pattern = AttackPatternFactory.create_single_shot(
    preload("res://scenes/bullets/scythe_bullet.tscn"), 5
  )
  pattern.target_group = "players"
  pattern.burst_delay = 5
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  pattern.penetration_count = -1

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 700
  movement_config.deceleration_rate = 100
  movement_config.min_speed = 400
  movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
  movement_config.bounce_factor = 1
  movement_config.max_bounces = 5
  movement_config.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
  movement_config.angular_velocity = 360

  var _visual_config = BulletVisualConfig.new()
  _visual_config.collision_radius = 0
  _visual_config.scale = 2.0

  pattern.bullet_visual_config = _visual_config

  pattern.bullet_movement_config = movement_config

  patterns.append(pattern)

  return patterns


func create_phase2_pattern() -> Array[AttackPattern]:
  """Phase2相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(10):
    var pattern = AttackPatternFactory.create_rapid_fire(
      preload("res://scenes/bullets/scythe_bullet.tscn"), 8, 2, 5
    )
    pattern.target_group = "players"
    pattern.burst_delay = 99
    pattern.direction_type = AttackPattern.DirectionType.FIXED
    pattern.base_direction = Vector2.RIGHT * (-1 if i % 2 == 1 else 1)
    pattern.spawn_position_mode = AttackPattern.SpawnPositionMode.FIXED_ABSOLUTE
    pattern.spawn_position_offset = Vector2.ZERO + Vector2(896 * (i % 2), 128 * i)
    pattern.persist_offscreen = true
    pattern.penetration_count = -1

    var movement_config = BulletMovementConfig.new()
    movement_config.initial_speed = 64
    movement_config.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
    movement_config.angular_velocity = 180 * (-1 if i % 2 == 1 else 1)

    pattern.bullet_movement_config = movement_config

    var _visual_config = BulletVisualConfig.new()
    _visual_config.collision_radius = 0
    _visual_config.scale = 2.0

    pattern.bullet_visual_config = _visual_config

    patterns.append(pattern)

  return patterns


func enable_phase_change():
  _phase_changable = true


func get_phase_changable() -> bool:
  return _phase_changable
