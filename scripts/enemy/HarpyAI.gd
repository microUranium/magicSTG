extends EnemyPatternedAIBase
class_name HarpyAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var attack_core_slot: UniversalAttackCoreSlot = null  # 攻撃コアをセットするスロット
@export var phase1_patterns: Array[AttackPattern]
@export var phase3_patterns_1: Array[AttackPattern]
@export var phase3_patterns_2: Array[AttackPattern]

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
  """攻撃パターンの初期化（パターンが未設定の場合のフォールバック）"""
  if phase1_patterns.is_empty():
    # Phase 1: 基本的なプレイヤー狙い射撃
    phase1_patterns = create_harpy_phase1_pattern()
    phase1_patterns.append(create_harpy_phase1_barrier())

  if phase3_patterns_1.is_empty():
    # Phase 3-1: バリア弾パターン
    phase3_patterns_1 = create_harpy_phase1_pattern()
    phase3_patterns_1.append(create_harpy_phase3_barrier2())

  if phase3_patterns_2.is_empty():
    # Phase 3-2: 高密度バリア弾
    phase3_patterns_2 = [create_harpy_phase3_barrier3()]


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

  if _phase_idx == 1:
    StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト
  elif _phase_idx == 3:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_request_change_background_scroll_speed(1000, 0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)

  _next_pattern()


func _next_pattern():
  super._next_pattern()

  if _phase_idx == 3 and _idx % patterns.size() == 10:
    _clear_all_pattern_cores()
    _set_attack_patterns(phase3_patterns_2)
  elif _phase_idx == 3 and _idx % patterns.size() == 0:
    _clear_all_pattern_cores()
    _set_attack_patterns(phase3_patterns_1)


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size() and (_phase_idx == 0 or _phase_idx == 2):
    _next_phase()
  else:
    super._on_pattern_finished(cb_token)


func _setup_phase_attacks():
  """フェーズに応じた攻撃パターンを設定"""
  match _phase_idx:
    1:
      # Phase 1: シンプルな攻撃
      _set_attack_patterns(phase1_patterns)
    2:
      # Phase 2: 攻撃停止
      _clear_all_pattern_cores()
    3:
      # Phase 3: バリア弾攻撃
      _set_attack_patterns(phase3_patterns_1)


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


func create_harpy_phase1_pattern() -> Array[AttackPattern]:
  """Phase1相当のパターンを作成"""
  var _patterns: Array[AttackPattern] = []

  for i in range(3):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 1, 1
    )
    pattern.target_group = "players"
    pattern.burst_delay = 3
    pattern.bullet_count = 3
    pattern.angle_spread = 30.0  # 各パターンで角度をずらす
    pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER

    var visual_config = (
      preload("res://resources/bulletVisuals/basic_bullet_standard.tres").duplicate()
    )
    visual_config.scale = 1.5
    visual_config.texture = preload("res://assets/gfx/sprites/bullet_harpy_sprite.png")
    pattern.bullet_visual_config = visual_config

    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
    movement_config.initial_speed = 500.0
    movement_config.deceleration_rate = 200.0
    movement_config.min_speed = 500.0 - (i * 50.0)
    pattern.bullet_movement_config = movement_config
    _patterns.append(pattern)

  return _patterns


func create_harpy_phase1_barrier() -> AttackPattern:
  """ハーピーPhase1のバリア弾パターンを作成"""
  var pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 8, 100.0, 3.0, 5
  )
  pattern.target_group = "players"
  pattern.burst_delay = 5
  pattern.rapid_fire_interval = 0

  var visual_config = (
    preload("res://resources/bulletVisuals/basic_bullet_standard.tres").duplicate()
  )
  visual_config.scale = 1.5
  pattern.bullet_visual_config = visual_config

  var movement_config = BarrierBulletMovement.new()
  movement_config.projectile_speed = 1000.0
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.FIXED
  pattern.barrier_movement_config = movement_config
  return pattern


func create_harpy_phase3_barrier2() -> AttackPattern:
  """ハーピーPhase3のバリア弾パターン2を作成（複数円）"""
  var inner_pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 8, 100.0, 2.5, 5
  )
  var outer_pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 8, 140.0, 2.5, 5
  )
  var layered_pattern = AttackPatternFactory.create_layered_pattern(
    [inner_pattern, outer_pattern], [0.0, 0.5]
  )
  inner_pattern.target_group = "players"
  outer_pattern.target_group = "players"
  inner_pattern.rapid_fire_interval = 0
  outer_pattern.rapid_fire_interval = 0

  layered_pattern.burst_delay = 4.5

  var visual_config = (
    preload("res://resources/bulletVisuals/basic_bullet_standard.tres").duplicate()
  )
  visual_config.scale = 1.5
  inner_pattern.bullet_visual_config = visual_config
  outer_pattern.bullet_visual_config = visual_config

  var movement_config = BarrierBulletMovement.new()
  movement_config.projectile_speed = 1000.0
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.TO_TARGET
  inner_pattern.barrier_movement_config = movement_config
  outer_pattern.barrier_movement_config = movement_config
  return layered_pattern


func create_harpy_phase3_barrier3() -> AttackPattern:
  """ハーピーPhase3のバリア弾パターン3を作成（高密度）"""
  var pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 16, 140.0, 0.25, 5
  )
  pattern.rotation_speed = 0  # 回転しない
  pattern.target_group = "players"
  pattern.target_group = "players"
  pattern.burst_delay = 0.5
  pattern.rapid_fire_interval = 0.0625

  var visual_config = (
    preload("res://resources/bulletVisuals/basic_bullet_standard.tres").duplicate()
  )
  visual_config.scale = 1.5
  pattern.bullet_visual_config = visual_config

  var movement_config = BarrierBulletMovement.new()
  movement_config.projectile_speed = 1000.0
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.TO_TARGET
  pattern.barrier_movement_config = movement_config
  return pattern
