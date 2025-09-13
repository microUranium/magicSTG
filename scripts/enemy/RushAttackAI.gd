extends EnemyAIBase
class_name RushAttackAI

@export var deal_damage_on_contact: bool = true
@export var direction_mode: DirectionMode = DirectionMode.TO_PLAYER
@export var fixed_angle: float = 0.0  # 度数で指定（DirectionMode.FIXED_ANGLEの場合）
@export var damage: int = 1  # プレイヤーに与えるダメージ

# === 回転設定 ===
@export var rotate_sprite: bool = true  # スプライトを向きに合わせて回転

# === 移動速度変更設定 ===
@export var change_speed: bool = false  # 移動速度を変更するか
@export var target_speed: float = 300.0  # 最終的な移動速度
@export var speed_change_rate: float = 200.0  # 移動速度を変更する速さ（units/sec）

enum DirectionMode { FIXED_ANGLE, TO_PLAYER }

var rush_direction: Vector2 = Vector2.ZERO
var is_rushing: bool = false
var current_speed: float = 0.0  # 現在の移動速度


func _ready():
  super._ready()
  await get_tree().process_frame
  _calculate_rush_direction()
  is_rushing = true

  # 初期速度設定
  current_speed = base_speed

  if deal_damage_on_contact:
    enemy_node.connect("area_entered", Callable(self, "_on_area_entered"))


func _process(delta):
  if not is_rushing or not enemy_node:
    return

  # スプライト回転処理
  if rush_direction != Vector2.ZERO and rotate_sprite:
    var rotation_angle = rush_direction.angle() - PI / 2
    enemy_node.rotation = rotation_angle

  # 移動速度変更処理
  if change_speed:
    _update_speed(delta)

  # 移動処理
  enemy_node.global_position += rush_direction * current_speed * delta

  # 画面外に出たら削除
  if _is_outside_screen():
    enemy_node.queue_free()


func _calculate_rush_direction():
  match direction_mode:
    DirectionMode.FIXED_ANGLE:
      var angle_rad = deg_to_rad(fixed_angle)
      rush_direction = Vector2(cos(angle_rad), sin(angle_rad))
    DirectionMode.TO_PLAYER:
      var player = _get_player()
      if player:
        rush_direction = (player.global_position - enemy_node.global_position).normalized()
        print_debug(
          (
            "RushAttackAI: Calculated rush direction player.global position: %s, enemy_node.global_position: %s, rush_direction: %s"
            % [player.global_position, enemy_node.global_position, rush_direction]
          )
        )
      else:
        # プレイヤーが見つからない場合は下方向に突進
        rush_direction = Vector2.DOWN


func _get_player() -> Node2D:
  var players = get_tree().get_nodes_in_group("players")
  if players.size() > 0:
    return players[0]
  return null


func _is_outside_screen() -> bool:
  var viewport_rect = PlayArea.get_play_rect()
  var pos = enemy_node.global_position
  var margin = 100.0  # 画面外への余裕

  return (
    pos.x < -margin
    or pos.x > viewport_rect.size.x + margin
    or pos.y < -margin
    or pos.y > viewport_rect.size.y + margin
  )


func stop_rushing():
  is_rushing = false


func start_rushing():
  _calculate_rush_direction()
  is_rushing = true
  current_speed = base_speed  # 速度をリセット


func _update_speed(delta: float):
  """移動速度を段階的に変更"""
  if abs(current_speed - target_speed) < speed_change_rate * delta:
    # 目標速度に十分近い場合は直接設定
    current_speed = target_speed
  else:
    # 段階的に変更
    if current_speed < target_speed:
      current_speed += speed_change_rate * delta
    else:
      current_speed -= speed_change_rate * delta


func _on_area_entered(body):
  # rush状態でのみプレイヤーにダメージを与える
  if body.is_in_group("players") and is_rushing:
    body.take_damage(damage)
