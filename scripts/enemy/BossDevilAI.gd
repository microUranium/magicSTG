extends EnemyPatternedAIBase
class_name BossDevilAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns: Array[AttackPattern]
@export var phase2_patterns_1: Array[AttackPattern]
@export var phase2_patterns_2: Array[AttackPattern]

@export var visual_config: BulletVisualConfig = null  # ビジュアル設定
@export var visual_config_fire: BulletVisualConfig = null  # ビジュアル設定（火）

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

var _phase_idx := 0


func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type

  _initialize_attack_patterns()

  super._ready()


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  if phase1_patterns.is_empty():
    phase1_patterns = create_phase1_pattern()
  if phase2_patterns_1.is_empty():
    phase2_patterns_1 = create_phase2_pattern_1()
  if phase2_patterns_2.is_empty():
    phase2_patterns_2 = create_phase2_pattern_2()


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
  elif _phase_idx == 3:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)

  phase_changed.emit(_phase_idx)

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size() and (_phase_idx == 0 or _phase_idx == 2):
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
      _clear_all_pattern_cores()
    4:
      _clear_all_pattern_cores()


func _next_pattern():
  super._next_pattern()
  if _phase_idx == 3 and (_idx % patterns.size() == 1 or _idx % patterns.size() == 5):
    _clear_all_pattern_cores()
    _set_attack_patterns(phase2_patterns_1)
  elif _phase_idx == 3 and (_idx % patterns.size() == 2 or _idx % patterns.size() == 6):
    _clear_all_pattern_cores()
    _set_attack_patterns(phase2_patterns_2)
  elif _phase_idx == 4 and _idx % patterns.size() == 3:
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", Vector2.ZERO, 0, 2)
    StageSignals.emit_signal("sfx_play_requested", "break_shield", Vector2.ZERO, 0, 2)
  elif _phase_idx == 4 and _idx % patterns.size() == 0:
    enemy_node.queue_free()  # 最終フェーズの最後のパターンが終わったら敵を消す


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
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 5, 0.5, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 1.5
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE
    pattern.bullet_count = 12
    pattern.bullet_speed = 300 - i * -40

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    patterns.append(pattern)

  for i in range(1):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 1, 0.3, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 5
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE
    pattern.bullet_count = 40
    pattern.bullet_speed = 50

    patterns.append(pattern)

  return patterns


func create_phase2_pattern_1() -> Array[AttackPattern]:
  """Phase2相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 5, 200.0, 0.5, 5
  )

  pattern.target_group = "players"
  pattern.rapid_fire_interval = 0
  pattern.burst_delay = 0.5

  # 画面外でも消えない設定
  pattern.persist_offscreen = true
  pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
  pattern.forced_lifetime = 3.0  # 最大3秒

  # 回転移動の設定
  var movement_config = BarrierBulletMovement.new()
  movement_config.projectile_speed = 1500.0
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.TO_TARGET
  movement_config.rotation_speed = 180.0
  movement_config.orbit_duration = 0.75
  movement_config.rotate_during_approach = true
  pattern.barrier_movement_config = movement_config

  if visual_config_fire != null:
    pattern.bullet_visual_config = visual_config_fire

  patterns.append(pattern)

  return patterns


func create_phase2_pattern_2() -> Array[AttackPattern]:
  """Phase2相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(2):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 20, 0.05, 3
    )
    pattern.target_group = "players"
    pattern.burst_delay = 3
    pattern.direction_type = AttackPattern.DirectionType.RANDOM

    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.HOMING
    movement_config.initial_speed = 500.0
    movement_config.homing_duration = 2.5
    movement_config.max_turn_angle_per_second = 120.0
    pattern.bullet_movement_config = movement_config

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    patterns.append(pattern)

  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 0.1, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 0.75
  pattern.bullet_count = 5
  pattern.angle_spread = 15.0  # 各パターンで角度をずらす
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER

  var movement_config = BulletMovementConfig.new()
  movement_config.movement_type = BulletMovementConfig.MovementType.STRAIGHT
  movement_config.initial_speed = 700.0
  pattern.bullet_movement_config = movement_config
  patterns.append(pattern)

  return patterns
