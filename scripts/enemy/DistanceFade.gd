extends Node

## プレイヤーとの距離に応じて、親（敵）の画像の透明度を変える部品。敵のシーンに子ノードとして置く。
## near_distance 以下では対象に元々設定されている透明度、far_distance 以上では min_alpha になり、
## その間は直線的に変化する。距離は実際のプレイヤーの位置で測る（迷彩の囮の位置は使わない）。
## 見た目だけを変え、当たり判定や攻撃には影響しない。

@export var target_path: NodePath = ^"../AnimatedSprite2D"  # 透明度を変える対象
@export var near_distance: float = 150.0  # これ以下の距離では元の透明度
@export var far_distance: float = 400.0  # これ以上の距離では min_alpha
@export_range(0.0, 1.0) var min_alpha: float = 0.1  # 最も離れたときの透明度

var _target: CanvasItem = null
var _max_alpha: float = 1.0  # 対象に元々設定されている透明度（近いときの透明度）


func _ready() -> void:
  _target = get_node_or_null(target_path) as CanvasItem
  if _target:
    _max_alpha = _target.modulate.a
  _update_alpha()


func _process(_delta: float) -> void:
  _update_alpha()


func get_max_alpha() -> float:
  return _max_alpha


func alpha_for_distance(distance: float) -> float:
  """距離 distance での透明度"""
  var span := far_distance - near_distance
  var t: float
  if span <= 0.0:
    t = 0.0 if distance <= near_distance else 1.0
  else:
    t = clampf((distance - near_distance) / span, 0.0, 1.0)
  return lerpf(_max_alpha, min_alpha, t)


func _update_alpha() -> void:
  if not is_instance_valid(_target):
    return
  var owner_node := get_parent() as Node2D
  var player := TargetService.get_player()
  var alpha := _max_alpha  # プレイヤーがいないとき（撃破後など）は元の透明度
  if owner_node and is_instance_valid(player):
    alpha = alpha_for_distance(owner_node.global_position.distance_to(player.global_position))
  # 色（被弾時の点滅など）はそのままに、透明度だけを変える
  _target.modulate.a = alpha
