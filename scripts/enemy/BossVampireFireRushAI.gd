extends EnemyAIBase
class_name BossVampireFireRushAI

@export var attack_patterns: Array[AttackPattern]
@export var visual_config_fire: BulletVisualConfig
@export var warning_config: AttackWarningConfig

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
    attack_patterns = [create_pattern()]

  set_attack_patterns(attack_patterns)
  await get_tree().process_frame
  attack_core_slot.trigger_all_cores()


func create_pattern() -> AttackPattern:
  var pattern = AttackPatternFactory.create_single_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 20
  )
  pattern.target_group = "players"
  pattern.auto_start = false
  pattern.bullet_speed = 1800.0
  pattern.auto_start = false
  var angle_rad = deg_to_rad(bullet_angle + 90)
  pattern.base_direction = Vector2(cos(angle_rad), sin(angle_rad)).normalized()
  pattern.direction_type = AttackPattern.DirectionType.FIXED

  if visual_config_fire:
    pattern.bullet_visual_config = visual_config_fire

  if warning_config:
    warning_config.angle_degrees = bullet_angle + 90
    pattern.warning_configs.append(warning_config)

  return pattern


func _process(delta: float) -> void:
  if not is_instance_valid(owner_original):
    enemy_node.queue_free()
    return


func cleanup():
  clear_all_pattern_cores()
  enemy_node.queue_free()
