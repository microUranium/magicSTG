extends Area2D
class_name WormSegment

# ワームの個別節を管理するクラス
# 前の節の過去位置を追従し、距離制約を適用

# 撃破エフェクト
@export
var destroy_particles_scene: PackedScene = preload("res://scenes/enemy/destroy_particle.tscn")

# 追従パラメータ
@export var follow_delay_frames: int = 4  # 追従遅延フレーム数
@export var segment_spacing: float = 18.0  # 理想的な節間距離
@export var max_distance: float = 30.0  # 最大許容距離
@export var min_distance: float = 10.0  # 最小許容距離

# 距離制約パラメータ
@export var spring_strength: float = 200.0  # バネ強度
@export var damping_factor: float = 0.8  # 減衰係数
@export var max_constraint_speed: float = 500.0  # 制約による最大移動速度

# 外部参照
var previous_segment: Node2D  # 前の節（頭部または前の節）
var head_worm_boss: Node  # 頭部のWormBossノード
var trail_system: TrailFollowSystem  # 前の節のTrailFollowSystem

# 内部状態
var current_velocity: Vector2 = Vector2.ZERO
var is_initialized: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready():
  # 当たり判定の設定
  add_to_group("enemies")


func setup(prev_segment: Node2D, worm_boss: Node, delay: int = 4):
  """節の初期設定"""
  previous_segment = prev_segment
  head_worm_boss = worm_boss
  follow_delay_frames = delay

  # 前の節のTrailFollowSystemを取得
  if previous_segment:
    trail_system = previous_segment.get_node("TrailFollowSystem")

  # 初期位置を設定
  if trail_system:
    var init_position = trail_system.get_position_at_delay(follow_delay_frames)
    var init_rotation = trail_system.get_rotation_at_delay(follow_delay_frames)
    global_position = init_position
    global_rotation = init_rotation
  elif previous_segment:
    global_position = previous_segment.global_position
    global_rotation = previous_segment.global_rotation

  is_initialized = true


func _process(delta):
  if not is_initialized or not previous_segment:
    return

  _update_follow_movement(delta)
  _apply_distance_constraints(delta)


func _update_follow_movement(delta):
  """追従移動の更新"""
  if not trail_system:
    print_debug("WormSegment: TrailFollowSystemが見つかりません - ", name)
    return

  # 目標位置と回転を取得
  var target_position = trail_system.get_position_at_delay(follow_delay_frames)
  var target_rotation = trail_system.get_rotation_at_delay(follow_delay_frames)

  # 位置の滑らかな移動
  var position_diff = target_position - global_position
  var distance_to_target = position_diff.length()

  if distance_to_target > segment_spacing:
    # 目標位置が遠い場合は追従
    var move_speed = min(distance_to_target * 2.0, 150.0)  # 距離に応じた速度調整
    var move_direction = position_diff.normalized()
    global_position += move_direction * move_speed * delta

  # 回転を移動方向にリアルタイムで合わせる
  if distance_to_target > 1.0:  # 移動している場合のみ回転
    var movement_direction = position_diff.normalized()
    var desired_rotation = movement_direction.angle() + PI * 1.5  # スプライトの向きに合わせて調整

    # 即座に目標回転に設定（滑らかな変化なし）
    global_rotation = desired_rotation


func _apply_distance_constraints(delta):
  """距離制約の適用（スプリング物理学）"""
  if not previous_segment:
    return

  var to_previous = previous_segment.global_position - global_position
  var distance = to_previous.length()

  # 距離制約チェック
  var constraint_force = Vector2.ZERO

  if distance > max_distance:
    # 離れすぎ - 強い引力
    var force_magnitude = (distance - segment_spacing) * spring_strength
    constraint_force = to_previous.normalized() * force_magnitude
  elif distance < min_distance:
    # 近すぎ - 反発力
    var force_magnitude = (min_distance - distance) * spring_strength
    constraint_force = -to_previous.normalized() * force_magnitude
  elif distance > segment_spacing * 1.2:
    # やや離れている - 軽い引力
    var force_magnitude = (distance - segment_spacing) * spring_strength * 0.3
    constraint_force = to_previous.normalized() * force_magnitude

  # 制約力を速度に適用
  if constraint_force.length() > 0:
    current_velocity += constraint_force * delta
    current_velocity *= damping_factor  # 減衰を適用

    # 最大速度制限
    if current_velocity.length() > max_constraint_speed:
      current_velocity = current_velocity.normalized() * max_constraint_speed

    # 位置更新
    global_position += current_velocity * delta


func take_damage(amount: int) -> void:
  """ダメージ処理"""
  if head_worm_boss and head_worm_boss.has_method("take_damage"):
    head_worm_boss.take_damage(amount)
  else:
    push_warning("WormSegment [", name, "]: WormBossのtake_damageメソッドが見つかりません")


func _normalize_angle(angle: float) -> float:
  """角度正規化"""
  while angle > PI:
    angle -= 2 * PI
  while angle < -PI:
    angle += 2 * PI
  return angle


func set_segment_spacing(spacing: float):
  """節間距離の設定"""
  segment_spacing = spacing
  max_distance = spacing * 1.8
  min_distance = spacing * 0.6


func get_follow_delay() -> int:
  """追従遅延フレーム数を取得"""
  return follow_delay_frames


func is_following_properly() -> bool:
  """正常に追従しているかをチェック"""
  if not previous_segment:
    return false

  var distance = global_position.distance_to(previous_segment.global_position)
  return distance <= max_distance * 1.5  # 許容範囲内かチェック


func _spawn_destroy_particles():
  if destroy_particles_scene:
    var p: CPUParticles2D = destroy_particles_scene.instantiate()
    get_tree().current_scene.add_child(p)
    p.global_position = global_position
    p.restart()
