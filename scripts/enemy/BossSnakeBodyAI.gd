extends EnemyAIBase
class_name BossSnakeBodyAI

var _parent_phase_idx: int = 0  # 現在のフェーズインデックス
var _destroy_attack_patterns: Array[AttackPattern] = []
var phase1_patterns: Array[AttackPattern] = []
var phase2_patterns: Array[AttackPattern] = []
var phase3_patterns: Array[AttackPattern] = []
var phase4_patterns: Array[AttackPattern] = []


func _ready():
  _initialize_attack_patterns()
  #ノードの削除時のシグナル
  connect("tree_exiting", Callable(self, "_on_tree_exiting"))

  super._ready()

  await get_tree().process_frame
  get_parent().head_worm_boss.connect("change_body_attack", Callable(self, "_setup_attack"))


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  phase1_patterns.append(create_phase1_pattern())
  phase1_patterns.append(create_body_destroy_pattern())

  phase2_patterns.append(create_phase2_pattern())

  phase3_patterns.append(create_phase3_pattern())

  phase4_patterns.append(create_phase4_pattern())

  set_attack_patterns(phase1_patterns)


func _setup_attack(_phase_idx: int):
  """フェーズに応じた攻撃パターンを設定"""
  clear_all_pattern_cores()
  match _phase_idx:
    3:
      set_attack_patterns(phase2_patterns)
    4:
      set_attack_patterns(phase3_patterns)
    5:
      set_attack_patterns(phase4_patterns)
    _:
      set_attack_patterns(phase1_patterns)


func create_phase1_pattern() -> AttackPattern:
  """フェーズ1のパターンを作成"""
  var pattern = AttackPatternFactory.create_single_circle_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 1, 2
  )
  pattern.target_group = "players"
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  pattern.burst_delay = 5

  var visual_config = BulletVisualConfig.new()
  visual_config.scale = 2
  visual_config.collision_radius = 16
  pattern.bullet_visual_config = visual_config

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 50
  movement_config.movement_type = BulletMovementConfig.MovementType.ACCELERATE
  movement_config.acceleration_rate = 100
  movement_config.min_speed = 250
  pattern.bullet_movement_config = movement_config

  return pattern


func create_body_destroy_pattern() -> AttackPattern:
  """胴体撃破時のパターンを作成"""
  var pattern = AttackPatternFactory.create_single_circle_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 12, 5
  )
  pattern.target_group = "players"
  pattern.direction_type = AttackPattern.DirectionType.RANDOM
  pattern.angle_spread = 360
  pattern.auto_start = false
  pattern.bullet_lifetime = 6.0

  var visual_config = BulletVisualConfig.new()
  visual_config.texture = preload("res://assets/gfx/sprites/bullet_snake_scale.png")
  visual_config.scale = 1
  visual_config.collision_radius = 10

  pattern.bullet_visual_config = visual_config

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 500
  movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
  movement_config.deceleration_rate = 500
  movement_config.min_speed = 50
  pattern.bullet_movement_config = movement_config

  return pattern


func create_phase2_pattern() -> AttackPattern:
  var pattern = AttackPatternFactory.create_single_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 5
  )
  pattern.target_group = "players"
  pattern.direction_type = AttackPattern.DirectionType.RANDOM
  pattern.angle_spread = 360
  pattern.bullet_speed = 500
  pattern.burst_delay = 2 + 0.5 * randf_range(0, 1)

  var visual_config = BulletVisualConfig.new()
  visual_config.texture = preload("res://assets/gfx/sprites/bullet_snake_scale.png")
  visual_config.scale = 1
  visual_config.collision_radius = 10
  pattern.bullet_visual_config = visual_config

  return pattern


func create_phase3_pattern() -> AttackPattern:
  var pattern = create_phase2_pattern()
  pattern.bullet_count = 2
  pattern.burst_delay = 1.5 + 0.5 * randf_range(0, 1)

  return pattern


func create_phase4_pattern() -> AttackPattern:
  var pattern = create_phase2_pattern()
  pattern.burst_delay = 0.5 + 0.3 * randf_range(0, 1)

  return pattern


func _on_tree_exiting():
  """ノードがツリーから削除される際に呼ばれる"""
  if is_instance_valid(attack_core_slot):
    attack_core_slot.trigger_all_cores()
