extends EnemyAIBase
class_name BatDecoyAI

# 状態定義
enum MovementState { ROTATION, STAY, INIT }  # 回転  # 停止  # 初期化

@export var attack_patterns: Array[AttackPattern]
@export var visual_config_dark: BulletVisualConfig
@export var positions: Array[Vector2] = [
  Vector2(64, 64), Vector2(832, 64), Vector2(832, 896), Vector2(64, 896)
]

var collision: CollisionShape2D

# 状態管理変数
var current_state: MovementState = MovementState.INIT
var current_tween: Tween = null
var state_timer: float = 0.0
var owner_original: Node = null  # オリジナルの敵ノードへの参照


func _ready():
  current_state = MovementState.INIT
  collision = enemy_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
  if collision:
    collision.disabled = true  # 初期状態でコリジョンを無効化
  super._ready()


func initialize(position_idx: int, original: Node2D):
  if not enemy_node:
    enemy_node = get_parent()

  owner_original = original
  enemy_node.global_position = owner_original.global_position

  var tween = enemy_node.create_tween()
  var target_pos = positions[position_idx % positions.size()]
  tween.tween_property(enemy_node, "global_position", target_pos, 3.0)
  tween.connect("finished", Callable(self, "_on_tween_completed"))


func start_attack():
  if collision:
    collision.disabled = false  # 攻撃開始時にコリジョンを有効化
  current_state = MovementState.STAY
  _initialize_attack_patterns()
  _check_state_transitions()


func _update_movement():
  match current_state:
    MovementState.ROTATION:
      _update_rotation_movement()
    MovementState.STAY:
      _update_stay_movement()


func _update_rotation_movement():
  if current_tween:
    return  # すでにtweenが動いている場合は何もしない

  # 現在位置から近いポジションを探索
  for pos in positions:
    if pos.distance_to(enemy_node.position) < 10.0:
      # 次のポジションへ移動
      var next_idx = (positions.find(pos) + 1) % positions.size()
      var next_pos = positions[next_idx]

      var tween = enemy_node.create_tween()
      tween.tween_property(enemy_node, "global_position", next_pos, 5.0)
      tween.connect("finished", Callable(self, "_on_tween_completed"))


func _update_stay_movement():
  # 3秒間停止
  await get_tree().create_timer(3.0).timeout
  _check_state_transitions()


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
  var pattern = AttackPatternFactory.create_rapid_fire(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 20, 0.7, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 0.7
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER

  var movement_config = BulletMovementConfig.new()
  movement_config.movement_type = BulletMovementConfig.MovementType.ACCELERATE
  movement_config.initial_speed = 50.0
  movement_config.acceleration_rate = 100.0
  movement_config.max_speed = 400.0
  pattern.bullet_movement_config = movement_config

  if visual_config_dark:
    pattern.bullet_visual_config = visual_config_dark

  return pattern


func _process(delta: float) -> void:
  if not is_instance_valid(owner_original):
    enemy_node.queue_free()
    return


func _check_state_transitions():
  match current_state:
    MovementState.ROTATION:
      _change_state(MovementState.STAY)
      _clear_all_pattern_cores()
    MovementState.STAY:
      _change_state(MovementState.ROTATION)
      set_attack_patterns(attack_patterns)

  _update_movement()


func _change_state(new_state: MovementState):
  if current_state != new_state:
    current_state = new_state


func _on_tween_completed():
  _check_state_transitions()


func cleanup():
  _clear_all_pattern_cores()
  enemy_node.queue_free()
