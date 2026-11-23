extends EnemyAIBase
class_name FireBallDecoyAI

# 状態定義
enum MovementState { MOVEMENT, STAY, INIT }  # 移動  # 停止  # 初期化

@export var attack_patterns: Array[AttackPattern]
@export var visual_config_dark: BulletVisualConfig
@export var positions: Array[Vector2] = [Vector2(64, 64), Vector2(384, 64), Vector2(832, 64)]
@export var damage: int = 10  # 体当たり攻撃のダメージ量
## 本体の HP がこの割合以下になるまで、最初の位置から動かない（その間も攻撃は続ける）。0 なら最初から動く
@export var move_start_hp_ratio: float = 0.4

var collision: CollisionShape2D

# 状態管理変数
var current_state: MovementState = MovementState.INIT
var current_tween: Tween = null
var state_timer: float = 0.0
var owner_original: Node = null  # オリジナルの敵ノードへの参照
var _move_unlocked := false  # 本体の HP が move_start_hp_ratio 以下になり、動いてよくなったか
var _waiting_for_unlock := false  # 停止時間を終え、動いてよくなるのを待っているか


func _ready():
  current_state = MovementState.INIT
  super._ready()


func initialize(position_idx: int, original: Node2D):
  if not enemy_node:
    enemy_node = get_parent()

  owner_original = original
  enemy_node.global_position = owner_original.global_position

  var tween = enemy_node.create_tween()
  var target_pos = positions[position_idx % positions.size()]
  tween.tween_property(enemy_node, "global_position", target_pos, 2.0)
  tween.connect("finished", Callable(self, "_on_tween_completed"))
  enemy_node.connect("area_entered", Callable(self, "_on_area_entered"))

  _move_unlocked = move_start_hp_ratio <= 0.0
  var hp_node = owner_original.get_node_or_null("HpNode")
  if hp_node:
    hp_node.hp_changed.connect(_on_owner_hp_changed)
    _on_owner_hp_changed(hp_node.current_hp, hp_node.max_hp)
  else:
    _move_unlocked = true


func _update_movement():
  match current_state:
    MovementState.MOVEMENT:
      _update_random_movement()
    MovementState.STAY:
      _update_stay_movement()


func _update_random_movement():
  if current_tween:
    return  # すでにtweenが動いている場合は何もしない

  # 行動範囲内でランダムに次の位置を選択
  var play_rect = PlayArea.get_play_rect()
  var margin = 32.0
  var min_x = play_rect.position.x + margin
  var max_x = play_rect.position.x + play_rect.size.x - margin
  var min_y = play_rect.position.y + margin
  var max_y = play_rect.position.y + play_rect.size.y - margin

  var next_pos = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))

  var tween = enemy_node.create_tween()
  tween.tween_property(enemy_node, "global_position", next_pos, 3.0)
  tween.connect("finished", Callable(self, "_on_tween_completed"))


func _update_stay_movement():
  # 5秒間停止
  await get_tree().create_timer(5.0, false).timeout
  if not _move_unlocked:
    _waiting_for_unlock = true  # 本体の HP が下がるまでこの場で攻撃を続ける
    return
  _check_state_transitions()


func _on_owner_hp_changed(current_hp: int, max_hp: int) -> void:
  if _move_unlocked or max_hp <= 0:
    return
  if current_hp <= max_hp * move_start_hp_ratio:
    _move_unlocked = true
    if _waiting_for_unlock:
      _waiting_for_unlock = false
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
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 20, 2, 3
  )
  pattern.target_group = "players"
  pattern.burst_delay = 2
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER

  var movement_config = BulletMovementConfig.new()
  movement_config.movement_type = BulletMovementConfig.MovementType.ACCELERATE
  movement_config.initial_speed = 5.0
  movement_config.acceleration_rate = 500.0
  movement_config.max_speed = 500.0
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
    MovementState.INIT:
      _change_state(MovementState.STAY)
      _initialize_attack_patterns()
    MovementState.MOVEMENT:
      _change_state(MovementState.STAY)
      set_attack_patterns(attack_patterns)
    MovementState.STAY:
      _change_state(MovementState.MOVEMENT)
      _clear_all_pattern_cores()

  _update_movement()


func _change_state(new_state: MovementState):
  if current_state != new_state:
    current_state = new_state


func _on_tween_completed():
  _check_state_transitions()


func cleanup():
  _clear_all_pattern_cores()
  enemy_node.queue_free()


func _on_area_entered(body):
  # 体当たり攻撃が可能な場合にプレイヤーにダメージを与える
  if body.is_in_group("players"):
    body.take_damage(damage)
