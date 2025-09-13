extends EnemyPatternedAIBase
class_name BossRobeAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns_1: Array[AttackPattern]
@export var phase1_patterns_2: Array[AttackPattern]
@export var phase2_patterns: Array[AttackPattern]
@export var clone_scene: PackedScene = preload("res://scenes/enemy/enemy_boss_robe_clone.tscn")

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

@export var animated_sprite: AnimatedSprite2D
@export var visual_config_dark: BulletVisualConfig

var _phase_idx := 0
var _target_position
var _clones: Array = []


func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type

  _initialize_attack_patterns()
  connect("tree_exiting", Callable(self, "_on_tree_exiting"))

  super._ready()


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  if phase1_patterns_1.is_empty():
    phase1_patterns_1 = [create_phase1_pattern_1()]
  if phase1_patterns_2.is_empty():
    phase1_patterns_2 = [create_phase1_pattern_2()]
  if phase2_patterns.is_empty():
    phase2_patterns = [create_phase2_pattern()]


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
  elif _phase_idx == 2:
    await _sprite_fade_out(0.5)
  elif _phase_idx == 3:
    _clear_all_pattern_cores()
    _spawn_clones(3)
    _sprite_fade_in(0.3)

  _next_pattern()


func _next_pattern():
  super._next_pattern()

  if _phase_idx == 1 and _idx % patterns.size() == 8:
    _clear_all_pattern_cores()
    _sprite_fade_out(1.0)
  elif _phase_idx == 1 and _idx % patterns.size() == 9:
    _clear_all_pattern_cores()
    _set_attack_patterns(phase1_patterns_2)
    _sprite_fade_in(0.3)
  elif _phase_idx == 1 and _idx % patterns.size() == 13:
    _clear_all_pattern_cores()
    _sprite_fade_in(1.0)
  elif _phase_idx == 1 and _idx % patterns.size() == 0:
    _set_attack_patterns(phase1_patterns_1)
  elif _phase_idx == 2 and _idx % patterns.size() == 0:
    _sprite_fade_out(0.5)
  elif _phase_idx == 2 and _idx % patterns.size() == 1:
    _sprite_fade_in(0.5)
    _set_attack_patterns(phase2_patterns)
    attack_core_slot.trigger_all_cores()
  elif _phase_idx == 3 and _idx % patterns.size() == 2:
    _sprite_fade_out(0.5)
  elif _phase_idx == 3 and _idx % patterns.size() == 0:
    _start_warp()
    _sprite_fade_in(0.5)


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
      _set_attack_patterns(phase1_patterns_1)
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


func create_phase1_pattern_1() -> AttackPattern:
  """Phase1相当のパターンを作成"""
  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 1, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 3
  pattern.bullet_count = 12
  pattern.direction_type = AttackPattern.DirectionType.CIRCLE

  var movement_config = BulletMovementConfig.new()
  movement_config.movement_type = BulletMovementConfig.MovementType.ACCELERATE
  movement_config.initial_speed = 100.0
  movement_config.acceleration_rate = 100.0
  movement_config.max_speed = 400.0
  movement_config.bounce_factor = 1
  movement_config.max_bounces = 1
  pattern.bullet_movement_config = movement_config

  var visual_config = BulletVisualConfig.new()
  visual_config.scale = 2
  visual_config.collision_radius = 16
  pattern.bullet_visual_config = visual_config

  return pattern


func create_phase1_pattern_2() -> AttackPattern:
  """Phase1相当のパターンを作成"""
  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 20, 0.2, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 0.2
  pattern.direction_type = AttackPattern.DirectionType.FIXED

  var movement_config = BulletMovementConfig.new()
  movement_config.movement_type = BulletMovementConfig.MovementType.HOMING
  movement_config.initial_speed = 200.0
  movement_config.homing_duration = 5.0
  movement_config.max_turn_angle_per_second = 180.0
  pattern.bullet_movement_config = movement_config

  if visual_config_dark:
    pattern.bullet_visual_config = visual_config_dark

  return pattern


func create_phase2_pattern() -> AttackPattern:
  """Phase2のバリア弾パターンを作成"""
  var pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 16, 100.0, 100.0, 5
  )
  pattern.target_group = "players"
  pattern.burst_delay = 30
  pattern.rapid_fire_interval = 0
  pattern.auto_start = false
  pattern.penetration_count = -1  # 無限貫通

  var visual_config = BulletVisualConfig.new()
  visual_config.scale = 2
  visual_config.collision_radius = 16
  visual_config.enable_particles = false
  pattern.bullet_visual_config = visual_config

  var movement_config = BarrierBulletMovement.new()
  movement_config.orbit_duration = -1  # 無限回転
  movement_config.rotation_speed = 180.0

  pattern.barrier_movement_config = movement_config

  return pattern


func _sprite_fade_in(duration := 1.0):
  """スプライトをフェードインさせる"""
  if animated_sprite:
    animated_sprite.modulate = Color(1, 1, 1, 0)
    var tween = create_tween()
    tween.tween_property(animated_sprite, "modulate:a", 1.0, duration)
    tween.play()
    await tween.finished


func _sprite_fade_out(duration := 1.0):
  """スプライトをフェードアウトさせる"""
  if animated_sprite:
    animated_sprite.modulate = Color(1, 1, 1, 1)
    var tween = create_tween()
    tween.tween_property(animated_sprite, "modulate:a", -1.0, duration)
    tween.play()
    await tween.finished


func _start_warp() -> void:
  # 座標計算
  var player = TargetService.get_player()

  if player:
    _target_position = WarpUtility.calculate_behind_position(
      player.global_position, Vector2.UP, Vector2(400, 400), 360, false
    )
  else:
    # プレイヤーが見つからない場合は元の位置を維持
    _target_position = enemy_node.global_position

  # 計算座標に瞬間移動
  enemy_node.global_position = _target_position


func _spawn_clones(count: int = 3) -> void:
  # クローンの生成
  var angle_offsets = [0, 180, 270]
  for i in range(count):
    var clone = clone_scene.instantiate()
    if is_instance_valid(clone):
      var clone_ai = clone.get_node_or_null("EnemyAI") as BossRobeCloneAI
      if clone_ai == null:
        push_error("Clone instance does not have BossRobeCloneAI script attached.")
        continue
      clone.global_position = (
        enemy_node.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
      )
      clone_ai.initialize(enemy_node, TargetService.get_player(), angle_offsets[i])
      clone_ai.max_alpha = 0.0
      _clones.append(clone_ai)
      get_tree().current_scene.add_child(clone)


func change_clones_alpha(target_alpha: float) -> void:
  for clone in _clones:
    if is_instance_valid(clone) and clone is BossRobeCloneAI:
      clone.max_alpha = target_alpha


func _on_tree_exiting() -> void:
  for clone in _clones:
    clone.cleanup()
  _clones.clear()
