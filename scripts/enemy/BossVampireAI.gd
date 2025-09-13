extends EnemyPatternedAIBase
class_name BossVampireAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns: Array[AttackPattern]
@export var phase3_patterns: Array[AttackPattern]
@export var phase5_patterns: Array[AttackPattern]

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

@export var decoy_scene: PackedScene = preload("res://scenes/enemy/enemy_bat_decoy.tscn")
@export
var firerush_scene: PackedScene = preload("res://scenes/enemy/enemy_boss_vampire_firerush.tscn")
@export var visual_config_dark: BulletVisualConfig

var animated_sprite: AnimatedSprite2D
var _phase_idx := 0
var _decoys: Array = []


func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type

  _initialize_attack_patterns()

  super._ready()


func _initialize_attack_patterns():
  """攻撃パターンの初期化（パターンが未設定の場合のフォールバック）"""
  if phase1_patterns.is_empty():
    phase1_patterns = create_phase1_patterns()
  if phase3_patterns.is_empty():
    phase3_patterns = create_phase3_patterns()
  if phase5_patterns.is_empty():
    phase5_patterns = create_phase5_patterns()


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

  if _phase_idx != 5:
    _setup_phase_attacks()

  if _phase_idx == 1:
    StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト
  elif _phase_idx == 3:
    _start_attack_decoys()
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)
  elif _phase_idx == 4:
    _destory_decoys()
  elif _phase_idx == 5:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)

  _next_pattern()


func _next_pattern():
  super._next_pattern()

  if _phase_idx == 2 and _idx % patterns.size() == 3:
    _spawn_decoys()
  if _phase_idx == 5 and _idx % patterns.size() == 0:
    _clear_all_pattern_cores()
  if _phase_idx == 5 and _idx % patterns.size() == 1:
    _clear_all_pattern_cores()
    _attack_firerush()
  if _phase_idx == 5 and _idx % patterns.size() == 2:
    _setup_phase_attacks()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size() and (_phase_idx == 0 or _phase_idx == 2 or _phase_idx == 4):
    _next_phase()
  else:
    super._on_pattern_finished(cb_token)


func _setup_phase_attacks():
  """フェーズに応じた攻撃パターンを設定"""
  match _phase_idx:
    1:
      set_attack_patterns(phase1_patterns)
    2:
      _clear_all_pattern_cores()
    3:
      set_attack_patterns(phase3_patterns)
    4:
      _clear_all_pattern_cores()
    5:
      set_attack_patterns(phase5_patterns)


func _clear_all_pattern_cores():
  """全てのパターンコアを削除"""
  for core in _pattern_cores:
    if is_instance_valid(core):
      attack_core_slot.remove_core(core)

  _pattern_cores.clear()


func create_phase1_patterns() -> Array[AttackPattern]:
  """Phase1のパターンを作成"""
  var patterns: Array[AttackPattern] = []
  for i in range(4):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 12, 0.1, 3
    )
    pattern.target_group = "players"
    pattern.direction_type = AttackPattern.DirectionType.FIXED
    pattern.angle_spread = 360
    pattern.angle_offset = 90 * i

    patterns.append(pattern)
  return patterns


func create_phase3_patterns() -> Array[AttackPattern]:
  """Phase3のパターンを作成"""
  var patterns: Array[AttackPattern] = []
  for i in range(8):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 5, 0.05, 3
    )
    pattern.target_group = "players"
    pattern.angle_offset = 360.0 / 8 * i
    pattern.angle_spread = 10
    pattern.burst_delay = 1
    pattern.direction_type = AttackPattern.DirectionType.FIXED

    patterns.append(pattern)

  return patterns


func create_phase5_patterns() -> Array[AttackPattern]:
  """Phase5のパターンを作成"""
  var patterns: Array[AttackPattern] = create_phase1_patterns()

  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 12, 0.2, 5
  )
  pattern.target_group = "players"
  pattern.angle_spread = 360
  pattern.burst_delay = 5
  pattern.direction_type = AttackPattern.DirectionType.FIXED

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 500.0
  movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
  movement_config.deceleration_rate = 300.0
  movement_config.min_speed = 200.0
  movement_config.bounce_factor = 1
  movement_config.max_bounces = 2
  pattern.bullet_movement_config = movement_config

  if visual_config_dark:
    pattern.bullet_visual_config = visual_config_dark

  patterns.append(pattern)

  return patterns


func _spawn_decoys():
  if not is_instance_valid(enemy_node):
    return

  var num_decoys = 4
  for i in range(num_decoys):
    var decoy = decoy_scene.instantiate() as Node2D
    if not decoy or not is_instance_valid(decoy):
      continue
    var decoy_ai = decoy.get_node_or_null("EnemyAI") as BatDecoyAI
    if decoy_ai:
      decoy_ai.initialize(i, enemy_node)
    _decoys.append(decoy)
    get_tree().current_scene.add_child(decoy)


func _start_attack_decoys():
  for decoy in _decoys:
    if is_instance_valid(decoy):
      var decoy_ai = decoy.get_node_or_null("EnemyAI") as BatDecoyAI
      if decoy_ai:
        decoy_ai.start_attack()


func _destory_decoys():
  for decoy in _decoys:
    if is_instance_valid(decoy):
      var decoy_ai = decoy.get_node_or_null("EnemyAI") as BatDecoyAI
      if decoy_ai:
        decoy_ai.cleanup()
  _decoys.clear()


func _spawn_firerush(angle: float, position: Vector2):
  if not is_instance_valid(enemy_node):
    return

  if not firerush_scene:
    push_error("Firerush scene not assigned.")
    return

  var firerush = firerush_scene.instantiate() as Node2D
  if not firerush or not is_instance_valid(firerush):
    return
  var firerush_ai = firerush.get_node_or_null("EnemyAI") as BossVampireFireRushAI
  if firerush_ai:
    firerush_ai.initialize(angle, enemy_node)
  get_tree().current_scene.add_child(firerush)
  firerush.global_position = position


func _attack_firerush():
  var attack_positions = [Vector2(895, 64), Vector2(895, 320), Vector2(895, 576), Vector2(895, 832)]
  var attack_angle = 90.0
  for pos in attack_positions:
    _spawn_firerush(attack_angle, pos)
    await get_tree().create_timer(0.05).timeout

  await get_tree().create_timer(1.0).timeout
  attack_positions = [Vector2(64, 1), Vector2(320, 1), Vector2(576, 1), Vector2(832, 1)]
  attack_angle = 0
  for pos in attack_positions:
    _spawn_firerush(attack_angle, pos)
    await get_tree().create_timer(0.05).timeout

  await get_tree().create_timer(1.0).timeout
  attack_positions = [Vector2(32, 1)]
  for i in range(18):
    _spawn_firerush(attack_angle, Vector2(attack_positions[0].x + i * 32, attack_positions[0].y))
    await get_tree().create_timer(0.05).timeout
  await get_tree().create_timer(0.7).timeout
  attack_positions = [Vector2(864, 1)]
  for i in range(18):
    _spawn_firerush(attack_angle, Vector2(attack_positions[0].x - i * 32, attack_positions[0].y))
    await get_tree().create_timer(0.05).timeout
