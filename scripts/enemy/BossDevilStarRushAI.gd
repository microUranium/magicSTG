extends EnemyAIBase
class_name BossDevilStarRushAI

@export var attack_patterns: Array[AttackPattern]
@export var visual_config_star: BulletVisualConfig

var owner_original: Node = null  # オリジナルの敵ノードへの参照
var bullet_angle


func _ready():
  super._ready()
  _initialize_attack_patterns()
  # 3秒後に自動的にクリーンアップ
  await get_tree().create_timer(3).timeout
  cleanup()


func initialize(angle: float, original: Node2D):
  if not enemy_node:
    enemy_node = get_parent()

  owner_original = original
  bullet_angle = angle


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  if attack_patterns.is_empty():
    attack_patterns = create_pattern()

  set_attack_patterns(attack_patterns)
  await get_tree().process_frame
  attack_core_slot.trigger_all_cores()


func create_pattern() -> Array[AttackPattern]:
  var patterns: Array[AttackPattern] = []
  var layered_patterns: Array[AttackPattern] = []
  for i in range(8):
    var pattern_charge = AttackPatternFactory.create_single_shot(
      AttackPatternFactory.DEFAULT_BULLET_SCENE, 0
    )
    pattern_charge.target_group = "players"
    pattern_charge.burst_delay = 20
    pattern_charge.spawn_position_mode = AttackPattern.SpawnPositionMode.RELATIVE_TO_OWNER
    pattern_charge.spawn_position_offset = Vector2(sin(deg_to_rad(45 * i)), cos(deg_to_rad(45 * i)))
    pattern_charge.bullet_lifetime = 0.45

    # 螺旋移動の設定
    var movement_config = BulletMovementConfig.new()
    movement_config.movement_type = BulletMovementConfig.MovementType.SPIRAL
    movement_config.initial_speed = 0.0
    movement_config.spiral_radius_growth = -250  # 半径増加速度
    movement_config.spiral_rotation_speed = 90.0
    movement_config.spiral_clockwise = false
    movement_config.spiral_phase_offset = 90.0 - (45.0 * i)
    movement_config.spiral_initial_radius = 250.0
    movement_config.rotation_mode = BulletMovementConfig.RotationMode.FIXED

    pattern_charge.bullet_movement_config = movement_config
    # 画面外でも消えない設定
    pattern_charge.persist_offscreen = true
    pattern_charge.max_offscreen_distance = 2000.0  # 発射位置から2000pxまで
    pattern_charge.forced_lifetime = 2.0  # 最大2秒
    if visual_config_star:
      pattern_charge.bullet_visual_config = visual_config_star

    patterns.append(pattern_charge)

  var pattern = AttackPatternFactory.create_single_shot(
    preload("res://scenes/bullets/star_bullet.tscn"), 20
  )
  pattern.target_group = "players"
  pattern.bullet_speed = 2500.0
  pattern.burst_delay = 20
  var angle_rad = deg_to_rad(bullet_angle + 90)
  pattern.base_direction = Vector2(cos(angle_rad), sin(angle_rad)).normalized()
  pattern.direction_type = AttackPattern.DirectionType.FIXED
  pattern.penetration_count = -1  # 貫通無限
  pattern.persist_offscreen = true
  pattern.max_offscreen_distance = 18000.0  # 発射位置から18000pxまで
  pattern.forced_lifetime = 5.0  # 最大5秒

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 2500.0
  movement_config.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
  movement_config.angular_velocity = 720.0  # 1秒間に2回転

  pattern.bullet_movement_config = movement_config

  patterns.append(pattern)

  var layered_pattern = AttackPatternFactory.create_layered_pattern(
    patterns, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.75]
  )
  layered_pattern.auto_start = false  # 自動開始を無効化

  layered_patterns.append(layered_pattern)

  return layered_patterns


func _process(delta: float) -> void:
  if not is_instance_valid(owner_original):
    enemy_node.queue_free()
    return


func cleanup():
  clear_all_pattern_cores()
  enemy_node.queue_free()
