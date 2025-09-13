extends EnemyAIBase
class_name BossRobeCloneAI

@export var attack_patterns: Array[AttackPattern]

@export var animated_sprite: AnimatedSprite2D
var _owner_sprite: AnimatedSprite2D

var max_alpha := 1.0
var owner_original: Node2D
var target_node: Node2D
var angle_offset := 0.0


func _ready():
  animated_sprite.modulate.a = 0.0
  _initialize_attack_patterns()

  super._ready()
  await get_tree().process_frame  # 1フレーム待つ
  attack_core_slot.trigger_all_cores()


func initialize(owner: Node2D, target: Node2D, angle: float = 0.0):
  """クローンの初期設定"""
  owner_original = owner
  target_node = target
  angle_offset = angle
  _owner_sprite = owner_original.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  if attack_patterns.is_empty():
    attack_patterns = [create_pattern()]

  set_attack_patterns(attack_patterns)


func _clear_all_pattern_cores():
  """全てのパターンコアを削除"""
  for core in _pattern_cores:
    if is_instance_valid(core):
      attack_core_slot.remove_core(core)

  _pattern_cores.clear()


func create_pattern() -> AttackPattern:
  """ダミーバリア弾パターンを作成"""
  var pattern = AttackPatternFactory.create_barrier_bullets(
    AttackPatternFactory.BARRIER_BULLET_SCENE, 16, 100.0, 100.0, 0
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
  movement_config.approach_duration = 0.1

  pattern.barrier_movement_config = movement_config

  return pattern


func _process(delta: float) -> void:
  if not is_instance_valid(owner_original) or not is_instance_valid(target_node):
    enemy_node.queue_free()
    return

  if animated_sprite and _owner_sprite:
    animated_sprite.modulate.a = clamp(_owner_sprite.modulate.a, 0, max_alpha)

  if owner_original and target_node:
    _culculate_position()


func _culculate_position():
  if is_instance_valid(owner_original) and is_instance_valid(target_node):
    var direction_to_target = (
      (target_node.global_position - owner_original.global_position).normalized()
    )
    var angle_to_target = direction_to_target.angle()
    var offset_distance = target_node.global_position.distance_to(owner_original.global_position)
    var offset = Vector2(0, offset_distance).rotated(deg_to_rad(angle_offset) + angle_to_target)
    enemy_node.global_position = target_node.global_position + offset


func cleanup():
  _clear_all_pattern_cores()
  enemy_node.queue_free()
