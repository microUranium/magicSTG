extends EnemyAIBase

@export var target_distance: float = 200.0  # プレイヤーとの目標距離
@export var distance_tolerance: float = 50.0  # 距離の許容誤差
@export var move_speed_multiplier: float = 1.0  # 移動速度の倍率
@export var enemy_separation_distance: float = 100.0  # 敵同士の最小距離
@export var separation_force: float = 1.5  # 敵同士の反発力の強さ

var player_node: Node2D


func _ready():
  super._ready()
  player_node = get_tree().current_scene.get_node("Player")


func _process(delta):
  if enemy_node and player_node:
    # プレイヤーとの距離維持
    var to_player = player_node.global_position - enemy_node.global_position
    var current_distance = to_player.length()
    var distance_difference = current_distance - target_distance

    var player_avoidance_direction = Vector2.ZERO

    # 許容誤差外であればプレイヤーとの距離を調整
    if abs(distance_difference) > distance_tolerance:
      if distance_difference < 0:
        # プレイヤーから離れる
        player_avoidance_direction = -to_player.normalized()
      else:
        # プレイヤーに近づく
        player_avoidance_direction = to_player.normalized()

      # 移動速度を距離の差に基づいて調整
      var speed_factor = abs(distance_difference) / target_distance
      speed_factor = clamp(speed_factor, 0.1, 2.0)
      player_avoidance_direction *= speed_factor

    # 敵同士の距離維持
    var enemy_separation_direction = _calculate_enemy_separation()

    # 最終的な移動方向を合成
    var final_direction = player_avoidance_direction + enemy_separation_direction

    # 移動を実行
    if final_direction.length() > 0:
      var move_speed = base_speed * move_speed_multiplier
      enemy_node.position += final_direction.normalized() * move_speed * delta


func _calculate_enemy_separation() -> Vector2:
  var separation_direction = Vector2.ZERO
  var enemy_count = 0

  # 現在のシーンから全ての敵を取得
  var enemies = get_tree().get_nodes_in_group("enemies")

  for enemy in enemies:
    if enemy == enemy_node:
      continue  # 自分自身は除外

    var to_enemy = enemy.global_position - enemy_node.global_position
    var distance = to_enemy.length()

    # 設定した分離距離内にいる場合
    if distance < enemy_separation_distance and distance > 0:
      # 距離が近いほど強い反発力
      var repulsion_strength = (enemy_separation_distance - distance) / enemy_separation_distance
      repulsion_strength = pow(repulsion_strength, 2)  # 非線形な反発力

      # 相手から離れる方向
      separation_direction -= to_enemy.normalized() * repulsion_strength * separation_force
      enemy_count += 1

  # 平均化して返す
  if enemy_count > 0:
    separation_direction /= enemy_count

  return separation_direction
