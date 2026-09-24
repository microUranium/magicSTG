extends Node

signal player_registered(player: Node2D)
signal player_unregistered
signal player_targetable_changed(targetable: bool)

var _current_player: Node2D = null
var _bullet_parent: Node = null

# 迷彩の加護など「狙われなくなる」効果用の状態。
# 敵の照準（自機狙い・追尾・追跡移動）だけが参照し、当たり判定には一切影響しない。
var _player_targetable: bool = true
var _decoy_position: Vector2 = Vector2.ZERO


func register_player(player: Node2D) -> void:
  if _current_player != player:
    _current_player = player
    set_player_targetable(true)
    emit_signal("player_registered", player)


func unregister_player() -> void:
  _current_player = null
  set_player_targetable(true)  # 次のプレイヤーへ状態を持ち越さない
  emit_signal("player_unregistered")


func get_player() -> Node2D:
  return _current_player


func get_player_position() -> Vector2:
  return _current_player.global_position if _current_player else Vector2.ZERO


#---------------------------------------------------------------------
# 照準（敵がプレイヤーを狙う）用 API
#---------------------------------------------------------------------
func set_player_targetable(targetable: bool, decoy_position: Vector2 = Vector2.ZERO) -> void:
  """プレイヤーを照準対象にできるかを設定する。

  targetable=false の間、敵の照準系は decoy_position（囮座標）を狙う。
  当たり判定は "players" グループで行われるため、この状態でも被弾はする。
  """
  _decoy_position = decoy_position
  if _player_targetable == targetable:
    return
  _player_targetable = targetable
  emit_signal("player_targetable_changed", targetable)


func is_player_targetable() -> bool:
  return _player_targetable


func get_aim_position() -> Vector2:
  """敵がプレイヤーを狙うときの座標。迷彩中は囮座標を返す。"""
  if not _player_targetable:
    return _decoy_position
  return get_player_position()


func get_aim_position_for(node: Node2D) -> Vector2:
  """ノード参照を保持している側向け。対象がプレイヤーなら照準座標へ読み替える。"""
  if not is_instance_valid(node):
    return Vector2.ZERO
  if node == _current_player:
    return get_aim_position()
  return node.global_position


func get_aim_target() -> Node2D:
  """照準対象としてのプレイヤーノード。迷彩中は null（＝狙えない）。"""
  return _current_player if _player_targetable else null


func set_bullet_parent(parent: Node) -> void:
  _bullet_parent = parent


func get_bullet_parent() -> Node:
  return _bullet_parent if _bullet_parent else get_tree().current_scene


func has_bullet_parent() -> bool:
  return _bullet_parent != null
