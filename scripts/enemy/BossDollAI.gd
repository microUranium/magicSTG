extends EnemyPatternedAIBase
class_name BossDollAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns: Array[AttackPattern]
@export var phase3_patterns1: Array[AttackPattern]
@export var phase3_patterns2: Array[AttackPattern]
@export var phase5_patterns1: Array[AttackPattern]
@export var phase5_patterns2: Array[AttackPattern]
@export var phase5_patterns3: Array[AttackPattern]
@export var phase5_patterns4: Array[AttackPattern]

@export var visual_config: BulletVisualConfig = null  # ビジュアル設定
@export var visual_config_note: BulletVisualConfig = null

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
  if phase3_patterns1.is_empty():
    phase3_patterns1 = create_phase3_pattern1()
  if phase3_patterns2.is_empty():
    phase3_patterns2 = create_phase5_pattern2()
  if phase5_patterns1.is_empty():
    phase5_patterns1 = create_phase5_pattern1()
  if phase5_patterns2.is_empty():
    phase5_patterns2 = create_phase5_pattern2()
  if phase5_patterns3.is_empty():
    phase5_patterns3 = create_phase5_pattern3()
  if phase5_patterns4.is_empty():
    phase5_patterns4 = create_phase5_pattern4()


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

  if _phase_idx == 3:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)
  elif _phase_idx == 5:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)
  elif _phase_idx == 6:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)

  _next_pattern()


func _next_pattern():
  super._next_pattern()
  if _phase_idx == 0 and _idx % patterns.size() == 4:
    StageSignals.emit_bgm_stop_requested(bgm_fade_in)  # BGM停止リクエスト
  elif _phase_idx == 0 and _idx % patterns.size() == 0:
    StageSignals.emit_bgm_play_requested(_bgm, 0, -10)  # BGM再生リクエスト
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_signal("sfx_play_requested", "girl_laugh", Vector2.ZERO, 0, 0)
  elif _phase_idx == 3 and (_idx % patterns.size() == 1 or _idx % patterns.size() == 7):
    _clear_all_pattern_cores()
    _set_attack_patterns(phase3_patterns1)
  elif _phase_idx == 3 and (_idx % patterns.size() == 2 or _idx % patterns.size() == 8):
    _clear_all_pattern_cores()
    _set_attack_patterns(phase3_patterns2)
  elif _phase_idx == 5 and _idx % patterns.size() == 1:
    _clear_all_pattern_cores()
    _set_attack_patterns(phase5_patterns1)
  elif _phase_idx == 5 and _idx % patterns.size() == 7:
    _clear_all_pattern_cores()
    _set_attack_patterns(phase5_patterns3)
  elif _phase_idx == 5 and (_idx % patterns.size() == 2 or _idx % patterns.size() == 8):
    _clear_all_pattern_cores()
    _set_attack_patterns(phase5_patterns2)


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size() and (_phase_idx == 0 or _phase_idx == 2 or _phase_idx == 4):
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
    6:
      _clear_all_pattern_cores()
      _set_attack_patterns(phase5_patterns4)
    7:
      _clear_all_pattern_cores()


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
  for i in range(6):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 12, 0.1, 3
    )
    pattern.target_group = "players"
    pattern.direction_type = AttackPattern.DirectionType.FIXED
    pattern.angle_spread = 360
    pattern.angle_offset = 60 * i
    pattern.burst_delay = 1

    patterns.append(pattern)

  for i in range(2):
    var pattern = AttackPatternFactory.create_single_shot(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 4
    pattern.bullet_count = 24
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = 100.0  # 半径増加速度
    movement_config.spiral_rotation_speed = 15.0
    movement_config.spiral_clockwise = (i % 2 == 0)  # 時計回り・反時計回り交互
    movement_config.spiral_phase_offset = 0.0  # 基準となる位相（各弾で自動的にずれる）

    pattern.bullet_movement_config = movement_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    patterns.append(pattern)

  return patterns


func create_phase3_pattern1() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(8):
    var pattern = AttackPatternFactory.create_single_shot(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 5
    )
    pattern.target_group = "players"
    pattern.burst_delay = 1
    pattern.spawn_position_mode = AttackPattern.SpawnPositionMode.RELATIVE_TO_TARGET
    pattern.spawn_position_offset = Vector2(
      sin(deg_to_rad(45 * i)) * 250, cos(deg_to_rad(45 * i)) * 250
    )

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = -100  # 半径増加速度
    movement_config.spiral_rotation_speed = 20.0
    movement_config.spiral_clockwise = false
    movement_config.spiral_phase_offset = 90.0 - (45.0 * i)
    movement_config.spiral_initial_radius = 250.0
    movement_config.rotation_mode = BulletMovementConfig.RotationMode.FIXED

    pattern.bullet_movement_config = movement_config
    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    if visual_config_note:
      pattern.bullet_visual_config = visual_config_note

    patterns.append(pattern)

  return patterns


func create_phase5_pattern1() -> Array[AttackPattern]:
  """Phase5相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(8):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 0.5, 5
    )
    pattern.target_group = "players"
    pattern.burst_delay = 2.5
    pattern.spawn_position_mode = AttackPattern.SpawnPositionMode.RELATIVE_TO_TARGET
    pattern.spawn_position_offset = Vector2(
      sin(deg_to_rad(45 * i)) * 250, cos(deg_to_rad(45 * i)) * 250
    )

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = -150  # 半径増加速度
    movement_config.spiral_rotation_speed = 30.0
    movement_config.spiral_clockwise = false
    movement_config.spiral_phase_offset = 90.0 - (45.0 * i)
    movement_config.spiral_initial_radius = 250.0
    movement_config.rotation_mode = BulletMovementConfig.RotationMode.FIXED

    pattern.bullet_movement_config = movement_config
    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    if visual_config_note:
      pattern.bullet_visual_config = visual_config_note

    patterns.append(pattern)

  return patterns


func create_phase5_pattern2() -> Array[AttackPattern]:
  """Phase5相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []
  for i in range(5):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 5, 0.3, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 1.5
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE
    pattern.bullet_count = 24

    var movement_config = BulletMovementConfig.new()
    movement_config.initial_speed = 500 - i * -80
    movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
    movement_config.deceleration_rate = 100
    movement_config.min_speed = 300
    pattern.bullet_movement_config = movement_config

    patterns.append(pattern)

  for i in range(2):
    var pattern = AttackPatternFactory.create_single_shot(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 4
    pattern.bullet_count = 24
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = 200.0  # 半径増加速度
    movement_config.spiral_rotation_speed = 15.0
    movement_config.spiral_clockwise = (i % 2 == 0)  # 時計回り・反時計回り交互
    movement_config.spiral_phase_offset = 0.0  # 基準となる位相（各弾で自動的にずれる）

    pattern.bullet_movement_config = movement_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    patterns.append(pattern)

  return patterns


func create_phase5_pattern3() -> Array[AttackPattern]:
  """Phase5相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_rapid_fire(
    preload("res://scenes/bullets/scythe_bullet.tscn"), 30, 0.12, 5
  )
  pattern.target_group = "players"
  pattern.burst_delay = 10
  pattern.direction_type = AttackPattern.DirectionType.RANDOM
  pattern.angle_spread = 75
  pattern.angle_offset = 180

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 450
  movement_config.movement_type = BulletMovementConfig.MovementType.GRAVITY
  movement_config.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
  movement_config.angular_velocity = 360

  var _visual_config = BulletVisualConfig.new()
  _visual_config.collision_radius = 0
  _visual_config.scale = 2.0

  # 画面外でも消えない設定
  pattern.persist_offscreen = true
  pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
  pattern.forced_lifetime = 5.0

  pattern.bullet_visual_config = _visual_config

  pattern.bullet_movement_config = movement_config

  patterns.append(pattern)

  return patterns


func create_phase5_pattern4() -> Array[AttackPattern]:
  """Phase5相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(8):
    var pattern = AttackPatternFactory.create_single_shot(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 5
    )
    pattern.target_group = "players"
    pattern.burst_delay = 0.4
    pattern.spawn_position_mode = AttackPattern.SpawnPositionMode.RELATIVE_TO_TARGET
    pattern.spawn_position_offset = Vector2(
      sin(deg_to_rad(45 * i)) * 250, cos(deg_to_rad(45 * i)) * 250
    )
    pattern.bullet_lifetime = 2.0

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = -200  # 半径増加速度
    movement_config.spiral_rotation_speed = 30.0
    movement_config.spiral_clockwise = false
    movement_config.spiral_phase_offset = 90.0 - (45.0 * i)
    movement_config.spiral_initial_radius = 250.0
    movement_config.rotation_mode = BulletMovementConfig.RotationMode.FIXED

    pattern.bullet_movement_config = movement_config
    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    if visual_config_note:
      pattern.bullet_visual_config = visual_config_note

    patterns.append(pattern)

  return patterns
