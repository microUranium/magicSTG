extends EnemyPatternedAIBase
class_name BossSpiderAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns: Array[AttackPattern]
@export var phase3_patterns: Array[AttackPattern]

@export var visual_config: BulletVisualConfig = null  # ビジュアル設定

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
  if phase3_patterns.is_empty():
    phase3_patterns = create_pattern_spidernet()


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
    _clear_all_pattern_cores()
    StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size() and (_phase_idx == 0 or _phase_idx == 2):
    _next_phase()
  else:
    super._on_pattern_finished(cb_token)


func _next_pattern():
  super._next_pattern()

  if _phase_idx == 1 and _idx % 4 == 2:
    _setup_phase_attacks()
  if _phase_idx == 1 and _idx % 4 == 3:
    _clear_all_pattern_cores()


func _setup_phase_attacks():
  """フェーズに応じた攻撃パターンを設定"""
  print_debug("Setting up phase attacks for phase index: ", _phase_idx)
  match _phase_idx:
    1:
      _set_attack_patterns(phase1_patterns)
    2:
      _clear_all_pattern_cores()
    3:
      _set_attack_patterns(phase3_patterns)


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


func create_pattern_spidernet() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(8):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 120, 0.05, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 0.05
    pattern.direction_type = AttackPattern.DirectionType.FIXED
    pattern.angle_spread = 90
    pattern.angle_offset = 45 * i
    pattern.bullet_speed = 600

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    patterns.append(pattern)

  for p in create_pattern_spidernet_horizontal():
    patterns.append(p)

  return patterns


func create_pattern_spidernet_horizontal() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(2):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 4, 2, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 2
    pattern.bullet_count = 36
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


func create_phase1_pattern() -> Array[AttackPattern]:
  """Phase1相当のパターンを作成 - 20発の螺旋弾を円形に発射"""
  var patterns: Array[AttackPattern] = []

  for i in range(5):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 1, 3
    )
    pattern.target_group = "players"
    pattern.burst_delay = 5
    pattern.bullet_count = 36
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = 300.0 - (i * 50.0)  # 半径増加速度
    movement_config.spiral_rotation_speed = 20.0
    movement_config.spiral_clockwise = true  # 時計回り
    movement_config.spiral_phase_offset = 0.0  # 基準となる位相（各弾で自動的にずれる）
    movement_config.spiral_acceleration = 0.0  # 加速度なし

    pattern.bullet_movement_config = movement_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    patterns.append(pattern)

  return patterns
