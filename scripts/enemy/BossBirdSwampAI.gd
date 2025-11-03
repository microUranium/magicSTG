extends EnemyPatternedAIBase
class_name BossBirdSwampAI

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
@export var phase1_patterns: Array[AttackPattern] = []
@export var phase3_patterns: Array[AttackPattern]
@export var phase5_patterns: Array[AttackPattern]
@export var warning_config: AttackWarningConfig

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

var _phase_idx := 0
var _harpy_swamp_ai: EnemyHarpySwampAI
var afterimage_scene: PackedScene = preload("res://scenes/effects/after_image.tscn")

@export var decoy_scene: PackedScene = preload("res://scenes/enemy/enemy_fire_ball_decoy.tscn")
var _decoys: Array = []

@export var afterimage_interval: float = 0.1  # 残像生成の間隔（秒）
var _is_afterimage_enabled: bool = false  # 残像生成フラグ
var _afterimage_timer: Timer


func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type

  _initialize_attack_patterns()
  _setup_afterimage_timer()

  super._ready()

  await get_tree().process_frame
  _harpy_swamp_ai = _get_harpy_swamp_ai()
  print_debug("BossBirdSwampAI: Linked to HarpySwampAI: ", _harpy_swamp_ai != null)


func _get_harpy_swamp_ai() -> EnemyHarpySwampAI:
  if not is_instance_valid(_harpy_swamp_ai):
    var harpy_swamp = get_tree().get_nodes_in_group("enemy_harpy_swamp")
    print_debug("BossBirdSwampAI: Found HarpySwamp enemies: ", harpy_swamp.size())
    if harpy_swamp.size() > 0:
      _harpy_swamp_ai = harpy_swamp[0].get_node_or_null("EnemyAI") as EnemyHarpySwampAI

  if _harpy_swamp_ai:
    _harpy_swamp_ai.connect("phases_changed", Callable(self, "_on_harpy_phases_changed"))

  return _harpy_swamp_ai


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  if phase1_patterns.is_empty():
    phase1_patterns = create_phase1_pattern()
  if phase3_patterns.is_empty():
    phase3_patterns = create_phase3_pattern()
  if phase5_patterns.is_empty():
    phase5_patterns = create_phase5_pattern()


func _setup_afterimage_timer():
  """残像生成タイマーの初期化"""
  _afterimage_timer = Timer.new()
  _afterimage_timer.wait_time = afterimage_interval
  _afterimage_timer.one_shot = false
  _afterimage_timer.timeout.connect(_on_afterimage_timer_timeout)
  add_child(_afterimage_timer)


func _on_afterimage_timer_timeout():
  """タイマータイムアウト時に残像を生成"""
  if _is_afterimage_enabled:
    _instantiate_afterimage_effect()


func enable_afterimage(enabled: bool):
  """残像生成の有効/無効を切り替え"""
  _is_afterimage_enabled = enabled
  if enabled and not _afterimage_timer.is_stopped():
    return

  if enabled:
    _afterimage_timer.start()
  else:
    _afterimage_timer.stop()


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
    attack_core_slot.trigger_all_cores()
  elif _phase_idx == 2 and not skip_bgm_change:
    enable_afterimage(false)
    StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト
  elif _phase_idx == 5:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)
    _spawn_decoys()
  elif _phase_idx == 6:
    _destory_decoys()

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if (
    _idx >= patterns.size()
    and (
      _phase_idx == 1
      or _phase_idx == 4
      or _phase_idx == 6
      or _phase_idx == 7
      or (_phase_idx == 2 and !_harpy_swamp_ai)
      or (_phase_idx == 0 and !_harpy_swamp_ai)
    )
  ):
    _next_phase()
  else:
    super._on_pattern_finished(cb_token)


func _on_harpy_phases_changed():
  """ハーピーのフェーズ変更に応じて自身のフェーズを変更"""
  if _phase_idx == 0:
    _next_phase()
  elif _phase_idx == 2:
    _next_phase()


func _next_pattern():
  super._next_pattern()

  if _phase_idx == 1 and _idx % patterns.size() == 1:
    enable_afterimage(true)

  if _phase_idx == 8 and _idx % 2 == 1:
    enable_afterimage(true)
  elif _phase_idx == 8 and _idx % 2 == 0:
    enable_afterimage(false)

  if _phase_idx == 9 and _idx % 2 == 0:
    enable_afterimage(true)
  elif _phase_idx == 9 and _idx % 2 == 1:
    enable_afterimage(false)


func _instantiate_afterimage_effect():
  """アフターイメージエフェクトの生成"""
  if not is_instance_valid(enemy_node):
    return

  var afterimage_instance = afterimage_scene.instantiate() as AfterImage
  if not afterimage_instance:
    return

  afterimage_instance.lifetime = 0.25
  var animated_sprite = enemy_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
  if animated_sprite:
    # AnimatedSprite2Dの現在のフレームのテクスチャを取得
    var sprite_frames = animated_sprite.sprite_frames
    if sprite_frames:
      var current_animation = animated_sprite.animation
      var current_frame = animated_sprite.frame
      var frame_texture = sprite_frames.get_frame_texture(current_animation, current_frame)

      if frame_texture:
        afterimage_instance.texture = frame_texture
        # AnimatedSprite2Dの位置、スケール、回転を反映
        afterimage_instance.global_position = animated_sprite.global_position
        afterimage_instance.global_rotation = animated_sprite.global_rotation
        # スケールはAnimatedSpriteとenemy_nodeの両方を考慮
        afterimage_instance.scale = enemy_node.scale * animated_sprite.scale
        afterimage_instance.flip_h = animated_sprite.flip_h
        afterimage_instance.flip_v = animated_sprite.flip_v

  get_tree().current_scene.add_child(afterimage_instance)


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
    4:
      _clear_all_pattern_cores()
    5:
      _set_attack_patterns(phase5_patterns)
    6:
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
  var patterns: Array[AttackPattern] = []
  var pattern = AttackPatternFactory.create_single_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 0
  )
  pattern.target_group = "players"
  pattern.auto_start = false
  pattern.bullet_speed = 1
  pattern.bullet_lifetime = 0.01
  pattern.base_direction = Vector2.UP
  pattern.direction_type = AttackPattern.DirectionType.FIXED

  if warning_config:
    pattern.warning_configs.append(warning_config)

  patterns.append(pattern)
  return patterns


func create_phase3_pattern() -> Array[AttackPattern]:
  """Phase3相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 16, 0.15, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 3
  pattern.bullet_count = 32
  pattern.direction_type = AttackPattern.DirectionType.CIRCLE

  pattern.bullet_speed = 500
  patterns.append(pattern)

  for i in range(5):
    var pattern2 = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 1.5, 5
    )
    pattern2.target_group = "players"
    pattern2.burst_delay = 5
    pattern2.direction_type = AttackPattern.DirectionType.TO_PLAYER
    pattern2.angle_spread = 40
    pattern2.bullet_speed = 400 - (i * 70)

    var visual_config = BulletVisualConfig.new()
    visual_config.scale = 3.0 - (i * 0.4)
    visual_config.collision_radius = 24.0 - (i * 3.2)
    pattern2.bullet_visual_config = visual_config

    patterns.append(pattern2)

  return patterns


func create_phase5_pattern() -> Array[AttackPattern]:
  """Phase5相当のパターンを作成"""
  var patterns: Array[AttackPattern] = []

  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 16, 0.15, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 3
  pattern.bullet_count = 32
  pattern.direction_type = AttackPattern.DirectionType.CIRCLE

  pattern.bullet_speed = 500
  patterns.append(pattern)

  for i in range(5):
    var pattern2 = AttackPatternFactory.create_rapid_fire(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 3, 1.5, 5
    )
    pattern2.target_group = "players"
    pattern2.burst_delay = 5
    pattern2.bullet_count = 3
    pattern2.direction_type = AttackPattern.DirectionType.TO_PLAYER
    pattern2.angle_spread = 40
    pattern2.bullet_speed = 400 - (i * 70)

    var visual_config = BulletVisualConfig.new()
    visual_config.scale = 3.0 - (i * 0.4)
    visual_config.collision_radius = 24.0 - (i * 3.2)
    pattern2.bullet_visual_config = visual_config

    patterns.append(pattern2)

  return patterns


func _spawn_decoys():
  if not is_instance_valid(enemy_node):
    return

  var num_decoys = 3
  for i in range(num_decoys):
    var decoy = decoy_scene.instantiate() as Node2D
    if not decoy or not is_instance_valid(decoy):
      continue
    var decoy_ai = decoy.get_node_or_null("EnemyAI") as FireBallDecoyAI
    if decoy_ai:
      decoy_ai.initialize(i, enemy_node)
    _decoys.append(decoy)
    get_tree().current_scene.add_child(decoy)


func _destory_decoys():
  for decoy in _decoys:
    if is_instance_valid(decoy):
      var decoy_ai = decoy.get_node_or_null("EnemyAI") as FireBallDecoyAI
      if decoy_ai:
        decoy_ai.cleanup()
  _decoys.clear()
