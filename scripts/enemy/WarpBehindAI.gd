# プレイヤーの背後にワープして攻撃するAI
extends EnemyAIBase
class_name WarpBehindAI

enum WarpState { WAITING, WARP_OUT, WARP_IN, ATTACKING }

# === エクスポート設定 ===
@export var warp_interval: float = 4.0  # ワープ間隔
@export var behind_distance_min: float = 120.0  # 背後最小距離
@export var behind_distance_max: float = 180.0  # 背後最大距離
@export var angle_variation: float = 30.0  # 角度揺らぎ（±度）
@export var attack_delay: float = 0.5  # ワープ後攻撃遅延
@export var warp_effect_duration: float = 0.3  # エフェクト持続時間
@export var warp_out_effect: PackedScene  # 消失エフェクト
@export var warp_in_effect: PackedScene  # 出現エフェクト

# === 内部状態 ===
var current_state: WarpState = WarpState.WAITING
var state_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var has_attacked: bool = false  # 攻撃実行フラグ


func _ready():
  super._ready()
  state_timer = warp_interval


func _process(delta):
  if not enemy_node:
    return

  state_timer += delta

  match current_state:
    WarpState.WAITING:
      _handle_waiting_state()
    WarpState.WARP_OUT:
      _handle_warp_out_state()
    WarpState.WARP_IN:
      _handle_warp_in_state()
    WarpState.ATTACKING:
      _handle_attacking_state()


func _handle_waiting_state() -> void:
  if state_timer >= warp_interval:
    _start_warp_out()


func _handle_warp_out_state() -> void:
  _start_warp_in()


func _handle_warp_in_state() -> void:
  _start_attacking()


func _handle_attacking_state() -> void:
  # 攻撃遅延後に攻撃実行
  if not has_attacked and state_timer >= attack_delay:
    _execute_attack()
    has_attacked = true

  # 即座に待機状態に戻る
  _start_waiting()


func _start_warp_out() -> void:
  current_state = WarpState.WARP_OUT
  state_timer = 0.0

  # 消失エフェクト生成
  WarpUtility.create_warp_effect(warp_out_effect, enemy_node.global_position, warp_effect_duration)

  # 敵を非表示
  enemy_node.modulate.a = 0.0

  # 背後座標計算
  var player = _get_player()
  if player:
    var player_facing = _get_player_facing(player)
    target_position = WarpUtility.calculate_behind_position(
      player.global_position,
      player_facing,
      Vector2(behind_distance_min, behind_distance_max),
      angle_variation
    )
  else:
    # プレイヤーが見つからない場合は元の位置を維持
    target_position = enemy_node.global_position


func _start_warp_in() -> void:
  current_state = WarpState.WARP_IN
  state_timer = 0.0

  # 計算座標に瞬間移動
  enemy_node.global_position = target_position

  # 出現エフェクト生成
  WarpUtility.create_warp_effect(warp_in_effect, target_position, warp_effect_duration)

  # 敵を表示
  enemy_node.modulate.a = 1.0


func _start_attacking() -> void:
  current_state = WarpState.ATTACKING
  state_timer = 0.0
  has_attacked = false


func _start_waiting() -> void:
  current_state = WarpState.WAITING
  state_timer = 0.0


func _execute_attack() -> void:
  if attack_core_slot:
    attack_core_slot.trigger_all_cores()


func _get_player() -> Node2D:
  var players = get_tree().get_nodes_in_group("players")
  if players.size() > 0:
    return players[0]
  return null


func _get_player_facing(player: Node2D) -> Vector2:
  # 後方攻撃モードが有効かどうかでプレイヤーの向きを判断
  if "_rear_mode" in player:
    var rear_mode = player._rear_mode
    if rear_mode:
      return Vector2.UP  # 後方攻撃モード時は上向き
    else:
      return Vector2.DOWN  # 通常時は下向き

  # フォールバック: プレイヤーが下を向いていると仮定
  return Vector2.DOWN
