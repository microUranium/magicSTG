extends EnemyPatternedAIBase
class_name BossDevilEnhancedAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns: Array[AttackPattern]
@export var phase2_patterns_1: Array[AttackPattern]
@export var phase2_patterns_2: Array[AttackPattern]
@export var phase3_patterns_1: Array[AttackPattern]
@export var phase3_patterns_2: Array[AttackPattern]
@export var phase3_patterns_3: Array[AttackPattern]
@export var phase3_patterns_4: Array[AttackPattern]
@export var phase4_patterns_1: Array[AttackPattern]
@export var phase4_patterns_2: Array[AttackPattern]

@export var visual_config: BulletVisualConfig = null  # ビジュアル設定
@export var visual_config_fire: BulletVisualConfig = null  # ビジュアル設定（火）
@export var visual_config_star: BulletVisualConfig = null  # ビジュアル設定（星）

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

@export
var starrush_scene: PackedScene = preload("res://scenes/enemy/enemy_boss_devil_starrush.tscn")
@export var attack_core_slot_final: UniversalAttackCoreSlot = null  # 攻撃コアをセットするスロット

var _phase_idx := 0
var _phase2_starrush_count := 0


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
  if phase3_patterns_1.is_empty():
    phase3_patterns_1 = create_phase3_pattern_1()
  if phase3_patterns_2.is_empty():
    phase3_patterns_2 = create_phase3_pattern_2()
  if phase3_patterns_3.is_empty():
    phase3_patterns_3 = create_phase3_pattern_3()
  if phase3_patterns_4.is_empty():
    phase3_patterns_4 = create_phase3_pattern_4()
  if phase4_patterns_1.is_empty():
    phase4_patterns_1 = create_phase4_pattern_1()
  if phase4_patterns_2.is_empty():
    phase4_patterns_2 = create_phase4_pattern_2()


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
  elif _phase_idx == 5:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)
  elif _phase_idx == 7:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)

  phase_changed.emit(_phase_idx)

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if (
    _idx >= patterns.size()
    and (
      _phase_idx == 0 or _phase_idx == 2 or _phase_idx == 4 or _phase_idx == 6 or _phase_idx == 7
    )
  ):
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
    5:
      _attack_phase3_rush()
    6:
      _clear_all_pattern_cores()
    7:
      _set_attack_patterns(phase4_patterns_1)
      _attack_final_rush()


func _next_pattern():
  super._next_pattern()
  if _phase_idx == 3 and (_idx % patterns.size() == 1 or _idx % patterns.size() == 9):
    _clear_all_pattern_cores()
    if _phase2_starrush_count == 0:
      _attack_starrush(0.625, 8)
    else:
      _attack_starrush(0.5, 10)
    _phase2_starrush_count += 1
  elif _phase_idx == 3 and (_idx % patterns.size() == 2 or _idx % patterns.size() == 10):
    _clear_all_pattern_cores()
    _set_attack_patterns(phase2_patterns_2)
  elif _phase_idx == 3 and (_idx % patterns.size() == 5 or _idx % patterns.size() == 13):
    _clear_all_pattern_cores()
    _set_attack_patterns(phase2_patterns_1)
  elif _phase_idx == 3 and (_idx % patterns.size() == 8 or _idx % patterns.size() == 0):
    _clear_all_pattern_cores()
  elif _phase_idx == 5 and _idx % patterns.size() == 3:
    _set_attack_patterns(phase3_patterns_2)
  elif _phase_idx == 5 and (_idx % patterns.size() == 10 or _idx % patterns.size() == 24):
    _clear_all_pattern_cores()
  elif _phase_idx == 5 and (_idx % patterns.size() == 11 or _idx % patterns.size() == 25):
    _set_attack_patterns(phase3_patterns_3)
  elif _phase_idx == 5 and _idx % patterns.size() == 15:
    _clear_all_pattern_cores()
    _attack_starrush_2(0.5, 10)
  elif _phase_idx == 5 and _idx % patterns.size() == 16:
    _clear_all_pattern_cores()
    _set_attack_patterns(phase3_patterns_2)
  elif _phase_idx == 5 and _idx % patterns.size() == 0:
    _attack_phase3_rush()


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


func _add_attack_patterns(patterns: Array[AttackPattern]):
  """攻撃パターンを追加（既存のパターンは保持）"""
  for pattern in patterns:
    var new_core = attack_core_slot.add_core(core_scene)
    if new_core:
      new_core.attack_pattern = pattern
      new_core.cooldown_sec = pattern.burst_delay
    _pattern_cores.append(new_core)


func _add_attack_patterns_to_final_slot(patterns: Array[AttackPattern]):
  """攻撃パターンを最終攻撃スロットに追加"""
  for pattern in patterns:
    var new_core = attack_core_slot_final.add_core(core_scene)
    if new_core:
      new_core.attack_pattern = pattern
      new_core.cooldown_sec = pattern.burst_delay
    _pattern_cores.append(new_core)


func _clear_all_pattern_cores():
  """全てのパターンコアを削除"""
  for core in _pattern_cores:
    if is_instance_valid(core):
      attack_core_slot.remove_core(core)

  _pattern_cores.clear()


func create_phase1_pattern() -> Array[AttackPattern]:
  """Phase1相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(1):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 8, 0.1, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 1.5
    pattern.bullet_count = 12
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = 350.0  # 半径増加速度
    movement_config.spiral_rotation_speed = 60.0
    movement_config.spiral_clockwise = 1
    movement_config.spiral_phase_offset = 0.0  # 基準となる位相（各弾で自動的にずれる）

    pattern.bullet_movement_config = movement_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 5.0  # 最大5秒

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    patterns.append(pattern)

  for i in range(1):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 1, 0.3, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 3.5
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE
    pattern.bullet_count = 40
    pattern.bullet_speed = 50

    patterns.append(pattern)

  return patterns


func create_phase2_pattern_1() -> Array[AttackPattern]:
  """Phase2相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 10, 150.0, 0.5, 5
  )

  pattern.target_group = "players"
  pattern.rapid_fire_interval = 0
  pattern.burst_delay = 10

  # 画面外でも消えない設定
  pattern.persist_offscreen = true
  pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
  pattern.forced_lifetime = 10.0  # 最大10秒

  # 回転移動の設定
  var movement_config = BarrierBulletMovement.new()
  movement_config.projectile_speed = 700.0
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.SPREAD
  movement_config.rotation_speed = 180.0
  movement_config.orbit_duration = 1
  movement_config.rotate_during_approach = true
  pattern.barrier_movement_config = movement_config

  if visual_config_star != null:
    pattern.bullet_visual_config = visual_config_star

  patterns.append(pattern)

  return patterns


func create_phase2_pattern_2() -> Array[AttackPattern]:
  """Phase2相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(1):
    var pattern = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 8, 0.1, 4
    )
    pattern.target_group = "players"
    pattern.burst_delay = 1.5
    pattern.bullet_count = 12
    pattern.direction_type = AttackPattern.DirectionType.CIRCLE

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = 350.0  # 半径増加速度
    movement_config.spiral_rotation_speed = 60.0
    movement_config.spiral_clockwise = 1
    movement_config.spiral_phase_offset = 0.0  # 基準となる位相（各弾で自動的にずれる）

    pattern.bullet_movement_config = movement_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 5.0  # 最大5秒

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

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


func create_phase3_pattern_1() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(4):
    var pattern = AttackPatternFactory.create_single_shot(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 3
    )
    pattern.target_group = "players"
    pattern.burst_delay = 20
    pattern.auto_start = false
    pattern.bullet_count = 2
    pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
    pattern.angle_spread = 60.0 + i * 30.0  # 各パターンで角度をずらす

    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = randi_range(50, 100)
    movement_config.spiral_radius_growth = randi_range(450, 600)
    movement_config.spiral_rotation_speed = randi_range(30, 90)
    movement_config.spiral_clockwise = i % 2 == 0
    movement_config.spiral_phase_offset = 0.0  # 基準となる位相（各弾で自動的にずれる）

    pattern.bullet_movement_config = movement_config

    if visual_config != null:
      pattern.bullet_visual_config = visual_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 20.0  # 最大20秒

    patterns.append(pattern)

  var pattern = AttackPatternFactory.create_single_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 20
  pattern.auto_start = false
  pattern.bullet_count = 1
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  pattern.angle_spread = 60.0 + randi_range(0, 3) * 30.0 * (randi_range(0, 1) * 2 - 1)  # ランダムに左右どちらかに角度をずらす

  var movement_config = BulletMovementConfig.new()
  movement_config.movement_type = BulletMovementConfig.MovementType.HOMING
  movement_config.initial_speed = 500
  movement_config.homing_duration = 1.2
  movement_config.max_turn_angle_per_second = 90

  pattern.bullet_movement_config = movement_config

  patterns.append(pattern)

  if visual_config != null:
    pattern.bullet_visual_config = visual_config

  # 画面外でも消えない設定
  pattern.persist_offscreen = true
  pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
  pattern.forced_lifetime = 20.0  # 最大20秒

  return patterns


func create_phase3_pattern_2() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 5, 0.3, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 0.3
  pattern.bullet_count = 32
  pattern.direction_type = AttackPattern.DirectionType.CIRCLE

  pattern.bullet_speed = 200
  patterns.append(pattern)

  pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 5, 0.3, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 0.3
  pattern.bullet_count = 32
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  pattern.angle_spread = 360.0

  pattern.bullet_speed = 300
  patterns.append(pattern)

  return patterns


func create_phase3_pattern_3() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 10, 150.0, 0.5, 5
  )

  pattern.target_group = "players"
  pattern.rapid_fire_interval = 0
  pattern.burst_delay = 10

  # 画面外でも消えない設定
  pattern.persist_offscreen = true
  pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
  pattern.forced_lifetime = 10.0  # 最大10秒

  # 回転移動の設定
  var movement_config = BarrierBulletMovement.new()
  movement_config.projectile_speed = 700.0
  movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.SPREAD
  movement_config.rotation_speed = 180.0
  movement_config.orbit_duration = 1
  movement_config.rotate_during_approach = true
  pattern.barrier_movement_config = movement_config

  if visual_config_star != null:
    pattern.bullet_visual_config = visual_config_star

  patterns.append(pattern)

  return patterns


func create_phase3_pattern_4() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_single_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 3
  )
  pattern.target_group = "players"
  pattern.auto_start = false
  pattern.burst_delay = 20
  pattern.bullet_count = 1
  pattern.direction_type = AttackPattern.DirectionType.CIRCLE
  pattern.angle_offset = 15 * randi_range(2, 4) * (randi_range(0, 1) * 2 - 1)
  pattern.penetration_count = -1

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 1000
  movement_config.bounce_factor = 1
  movement_config.max_bounces = 3
  movement_config.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
  movement_config.angular_velocity = 360

  if visual_config_star != null:
    var visual_config_copy = visual_config_star.duplicate() as BulletVisualConfig
    visual_config_copy.scale = visual_config_star.scale * 3
    visual_config_copy.collision_radius = visual_config_star.collision_radius * 3
    pattern.bullet_visual_config = visual_config_copy

  # 画面外でも消えない設定
  pattern.persist_offscreen = true
  pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
  pattern.forced_lifetime = 10.0  # 最大10秒

  pattern.bullet_movement_config = movement_config

  patterns.append(pattern)

  return patterns


func create_phase4_pattern_1() -> Array[AttackPattern]:
  """Phase4相当のパターンを作成"""
  var layered_patterns: Array[AttackPattern] = []
  var patterns: Array[AttackPattern] = []

  var bullet_counts = [5, 8, 10, 12]
  var bullet_radiuses = [100, 300, 500, 700]
  var bullet_approach_durations = [1.0, 1.5, 2.0, 2.5]

  for i in range(bullet_counts.size()):
    var pattern = AttackPatternFactory.create_barrier_bullets(
      AttackPatternFactory.BARRIER_BULLET_SCENE, bullet_counts[i], bullet_radiuses[i], 60, 5
    )

    pattern.target_group = "players"
    pattern.rapid_fire_interval = 0
    pattern.burst_delay = 1000
    pattern.penetration_count = -1

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 3.0  # 最大3秒

    # 回転移動の設定
    var movement_config = BarrierBulletMovement.new()
    movement_config.projectile_speed = 1500.0
    movement_config.approach_duration = bullet_approach_durations[i]
    movement_config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.TO_TARGET
    movement_config.rotation_speed = 30.0
    movement_config.orbit_duration = 60
    movement_config.rotate_during_approach = true
    pattern.barrier_movement_config = movement_config

    if visual_config_fire != null:
      pattern.bullet_visual_config = visual_config_fire

    patterns.append(pattern)

  var layered_pattern = AttackPatternFactory.create_layered_pattern(patterns, [0.0, 5.0, 5.0, 5.0])
  layered_pattern.burst_delay = 1000

  layered_patterns.append(layered_pattern)

  return layered_patterns


func create_phase4_pattern_2(count = 5) -> Array[AttackPattern]:
  """Phase4相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  for i in range(count):
    var pattern = AttackPatternFactory.create_single_shot(
      preload("res://scenes/bullets/final_star_bullet.tscn"), 5
    )
    pattern.target_group = "players"
    pattern.burst_delay = 60
    pattern.auto_start = false
    pattern.direction_type = AttackPattern.DirectionType.TO_OWNER
    pattern.spawn_position_mode = AttackPattern.SpawnPositionMode.RELATIVE_TO_OWNER

    var random_angle = randi_range(0, 360)
    pattern.spawn_position_offset = Vector2(
      sin(deg_to_rad(random_angle)) * 700, cos(deg_to_rad(random_angle)) * 700
    )

    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.ACCELERATE
    movement_config.initial_speed = 200
    movement_config.acceleration_rate = 100
    movement_config.max_speed = 400
    movement_config.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
    movement_config.angular_velocity = 360
    pattern.bullet_movement_config = movement_config

    # 画面外でも消えない設定
    pattern.persist_offscreen = true
    pattern.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern.forced_lifetime = 10.0  # 最大10秒

    patterns.append(pattern)

  return patterns


func _spawn_starrush(angle: float, position: Vector2):
  if not is_instance_valid(enemy_node):
    return

  if not starrush_scene:
    push_error("Firerush scene not assigned.")
    return

  var starrush = starrush_scene.instantiate() as Node2D
  if not starrush or not is_instance_valid(starrush):
    return
  var starrush_ai = starrush.get_node_or_null("EnemyAI") as BossDevilStarRushAI
  if starrush_ai:
    starrush_ai.initialize(angle, enemy_node)
  get_tree().current_scene.add_child(starrush)
  starrush.global_position = position


func _attack_starrush(delay = 0.5, count = 10, _phase = 3):
  var attack_positions_x = [64, 320, 576, 832]
  var attack_positions_y = 1
  var attack_angle = 0

  for i in range(count):
    if _phase_idx != _phase:
      return  # フェーズが変わったら攻撃を中止
    var randomIndex = randi() % attack_positions_x.size()
    if i % 2 == 0:
      attack_angle = 0
      attack_positions_y = 1
    else:
      attack_angle = 180
      attack_positions_y = 896
    _spawn_starrush(attack_angle, Vector2(attack_positions_x[randomIndex], attack_positions_y))
    await get_tree().create_timer(delay).timeout


func _attack_starrush_2(delay = 0.5, count = 10, _phase = 5):
  var attack_positions_x = [64, 832]
  var attack_positions_y = [1, 896]
  var attack_angle = 0

  for i in range(count):
    if _phase_idx != _phase:
      return  # フェーズが変わったら攻撃を中止
    var randomPos = Vector2(
      randi_range(attack_positions_x[0], attack_positions_x[1]),
      randi_range(attack_positions_y[0], attack_positions_y[1])
    )

    attack_angle = (
      TargetService.get_player_position().direction_to(randomPos).angle() * 180 / PI + 90
    )  # プレイヤーに向かう角度を計算

    _spawn_starrush(attack_angle, randomPos)
    await get_tree().create_timer(delay).timeout


func _attack_phase3_rush(delay = 0.3, count = 10, _phase = 5):
  for i in range(count):
    if _phase_idx != _phase:
      _clear_all_pattern_cores()
      return  # フェーズが変わったら攻撃を中止

    phase3_patterns_1 = create_phase3_pattern_1()  # パターンを更新して角度をずらす
    _add_attack_patterns(phase3_patterns_1)

    if i < 3:
      phase3_patterns_4 = create_phase3_pattern_4()  # パターンを更新して角度をずらす
      _add_attack_patterns(phase3_patterns_4)

    await get_tree().process_frame
    attack_core_slot.trigger_all_cores()
    await get_tree().create_timer(delay).timeout
  await get_tree().create_timer(1).timeout
  _clear_all_pattern_cores()  # ラッシュ終了後に全てのパターンコアを削除


func _attack_final_rush():
  var delays = [0.5, 0.45, 0.38, 0.3]
  var counts = [5, 6, 7, 8]
  var delay_count = 0
  await get_tree().create_timer(1).timeout

  var c = 0
  var d = 0.5

  while delay_count < 43:
    if delay_count < 5:
      c = counts[0]
      d = delays[0]
    elif delay_count < 15:
      c = counts[1]
      d = delays[1]
    elif delay_count < 20:
      c = counts[2]
      d = delays[2]
    elif delay_count < 30:
      c = counts[3]
      d = delays[3]

    var final_patterns = create_phase4_pattern_2(c)  # 最終ラッシュ用のパターンを作成
    _add_attack_patterns_to_final_slot(final_patterns)  # 最終攻撃スロットにパターンを追加
    await get_tree().process_frame

    attack_core_slot_final.trigger_all_cores()  # 全てのコアをトリガーして攻撃開始

    await get_tree().create_timer(d).timeout  # 遅延時間を段階的に短く
    delay_count += d
