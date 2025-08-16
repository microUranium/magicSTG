extends EnemyPatternedAIBase
class_name WormBossAI

# 状態定義
enum MovementState { CHASE, CIRCLE, RUSH, PATTERN }  # 追尾  # 包囲旋回  # 突進  # パターン攻撃

# 移動パラメータ
@export var max_turn_rate: float = 120.0

# 追尾状態パラメータ
@export var chase_min_speed: float = 50.0
@export var chase_max_speed: float = 200.0
@export var chase_speed_range: float = 500.0

# 包囲旋回状態パラメータ
@export var circle_speed: float = 120.0
@export var circle_radius: float = 250.0

# 突進状態パラメータ
@export var rush_speed: float = 300.0
@export var rush_duration: float = 1.5

# 遷移条件パラメータ
@export var chase_to_circle_distance: float = 300.0
@export var circle_to_rush_min_distance: float = 160.0
@export var circle_to_rush_max_distance: float = 400.0
@export var circle_to_chase_distance: float = 500.0
@export var circle_to_rush_time: float = 5.0
@export var circle_max_time: float = 8.0

# 状態管理変数
var current_state: MovementState = MovementState.CHASE
var state_timer: float = 0.0
var current_facing_angle: float = 0.0
var target_player: Node2D = null
var prev_position: Vector2 = Vector2.ZERO

# 突進用変数
var rush_target_position: Vector2


func _ready():
  _find_player()
  super._ready()


func _process(delta: float):
  if not enemy_node or not target_player:
    return

  state_timer += delta
  _check_state_transitions()
  _update_movement(delta)


func _find_player():
  var players = get_tree().get_nodes_in_group("players")
  if players.size() > 0:
    target_player = players[0]


func _update_movement(delta: float):
  if not target_player:
    return

  match current_state:
    MovementState.CHASE:
      _update_chase_movement(delta)
    MovementState.CIRCLE:
      _update_circle_movement(delta)
    MovementState.RUSH:
      _update_rush_movement(delta)
    MovementState.PATTERN:
      _check_pattern_movement(delta)


func _update_chase_movement(delta: float):
  var target_position = target_player.global_position
  var current_position = enemy_node.global_position
  var distance_to_player = current_position.distance_to(target_position)

  # プレイヤーへの方向を計算
  var desired_direction = (target_position - current_position).normalized()
  var desired_angle = desired_direction.angle()

  # 角度制限付き旋回
  var angle_diff = _normalize_angle(desired_angle - current_facing_angle)
  var max_turn_this_frame = deg_to_rad(max_turn_rate) * delta

  if abs(angle_diff) > max_turn_this_frame:
    current_facing_angle += sign(angle_diff) * max_turn_this_frame
  else:
    current_facing_angle = desired_angle

  current_facing_angle = _normalize_angle(current_facing_angle)

  # 距離に応じて速度を調整（遠いほど速い）
  var speed_factor = clamp(distance_to_player / chase_speed_range, 0.0, 1.0)
  var current_speed = lerp(chase_min_speed, chase_max_speed, speed_factor)

  # 移動実行
  var movement_direction = Vector2(cos(current_facing_angle), sin(current_facing_angle))
  enemy_node.global_position += movement_direction * current_speed * delta

  # スプライト回転
  enemy_node.rotation = current_facing_angle + PI * 1.5


func _update_circle_movement(delta: float):
  var target_position = target_player.global_position
  var current_position = enemy_node.global_position
  var to_player = target_position - current_position
  var distance_to_player = to_player.length()

  # プレイヤーから理想距離への方向ベクトル
  var radius_error = distance_to_player - circle_radius
  var radial_direction = to_player.normalized()

  # 接線方向（反時計回り）
  var tangent_direction = Vector2(-radial_direction.y, radial_direction.x)

  # 移動ベクトル合成（接線方向 + 距離補正）
  var movement_vector = tangent_direction * circle_speed
  if abs(radius_error) > 10.0:  # 理想距離から離れすぎている場合
    movement_vector += radial_direction * -radius_error * 0.5

  # 角度制限付き旋回
  var desired_angle = movement_vector.normalized().angle()
  var angle_diff = _normalize_angle(desired_angle - current_facing_angle)
  var max_turn_this_frame = deg_to_rad(max_turn_rate) * delta

  if abs(angle_diff) > max_turn_this_frame:
    current_facing_angle += sign(angle_diff) * max_turn_this_frame
  else:
    current_facing_angle = desired_angle

  current_facing_angle = _normalize_angle(current_facing_angle)

  # 移動実行
  var movement_direction = Vector2(cos(current_facing_angle), sin(current_facing_angle))
  enemy_node.global_position += movement_direction * movement_vector.length() * delta

  # スプライト回転
  enemy_node.rotation = current_facing_angle + PI * 1.5


func _update_rush_movement(delta: float):
  # 突進方向を計算
  var to_target = rush_target_position - enemy_node.global_position
  var desired_angle = to_target.angle()

  # 角度制限付き旋回（突進時は少し速めに）
  var angle_diff = _normalize_angle(desired_angle - current_facing_angle)
  var max_turn_this_frame = deg_to_rad(max_turn_rate * 1.5) * delta

  if abs(angle_diff) > max_turn_this_frame:
    current_facing_angle += sign(angle_diff) * max_turn_this_frame
  else:
    current_facing_angle = desired_angle

  current_facing_angle = _normalize_angle(current_facing_angle)

  # 移動実行
  var movement_direction = Vector2(cos(current_facing_angle), sin(current_facing_angle))
  enemy_node.global_position += movement_direction * rush_speed * delta

  # スプライト回転
  enemy_node.rotation = current_facing_angle + PI * 1.5


func _check_pattern_movement(delta: float):
  var current_position = enemy_node.global_position
  if prev_position == current_position:
    # 動いていない場合はスキップ
    return

  var movement_direction = (current_position - prev_position).normalized()
  var desired_angle = movement_direction.angle()

  # 角度制限付き旋回
  var angle_diff = _normalize_angle(desired_angle - current_facing_angle)
  var max_turn_this_frame = deg_to_rad(360) * delta

  if abs(angle_diff) > max_turn_this_frame:
    current_facing_angle += sign(angle_diff) * max_turn_this_frame
  else:
    current_facing_angle = desired_angle

  current_facing_angle = _normalize_angle(current_facing_angle)

  # スプライト回転
  enemy_node.rotation = current_facing_angle + PI * 1.5
  prev_position = current_position


func _check_state_transitions():
  var target_position = target_player.global_position
  var current_position = enemy_node.global_position
  var distance_to_player = current_position.distance_to(target_position)

  match current_state:
    MovementState.CHASE:
      # 追尾 → 包囲旋回
      if distance_to_player <= chase_to_circle_distance:
        _change_state(MovementState.CIRCLE)

    MovementState.CIRCLE:
      # 包囲旋回 → 突進
      if (
        state_timer >= circle_to_rush_time
        and distance_to_player >= circle_to_rush_min_distance
        and distance_to_player <= circle_to_rush_max_distance
      ):
        rush_target_position = target_position  # 突進目標を記録
        _change_state(MovementState.RUSH)
      # 包囲旋回 → 追尾
      elif distance_to_player >= circle_to_chase_distance or state_timer >= circle_max_time:
        _change_state(MovementState.CHASE)

    MovementState.RUSH:
      # 突進 → 追尾
      if state_timer >= rush_duration:
        _change_state(MovementState.CHASE)


func _change_state(new_state: MovementState):
  if current_state != new_state:
    current_state = new_state
    state_timer = 0.0


func _normalize_angle(angle: float) -> float:
  while angle > PI:
    angle -= 2 * PI
  while angle < -PI:
    angle += 2 * PI
  return angle
