extends Node
class_name TrailFollowSystem

# 位置履歴管理システム
# 各フレームの位置を記録し、遅延アクセスを提供

@export var history_size: int = 15  # 保持する履歴フレーム数
@export var update_every_frames: int = 1  # 記録頻度（1=毎フレーム）

# 位置履歴データ
var position_history: Array[Vector2] = []
var rotation_history: Array[float] = []
var frame_counter: int = 0

# 追従対象ノード
var target_node: Node2D


func _ready():
  target_node = get_parent() as Node2D
  if not target_node:
    push_error("TrailFollowSystem: 親ノードがNode2Dではありません")
    return

  # 初期位置で履歴を埋める
  _initialize_history()


func _process(_delta):
  frame_counter += 1

  if frame_counter % update_every_frames == 0:
    _record_position()


func _initialize_history():
  """初期位置で履歴配列を初期化"""
  var initial_position = target_node.global_position
  var initial_rotation = target_node.global_rotation

  position_history.clear()
  rotation_history.clear()

  for i in range(history_size):
    position_history.append(initial_position)
    rotation_history.append(initial_rotation)


func _record_position():
  """現在位置を履歴に記録"""
  if not target_node:
    return

  # 新しい位置を先頭に追加
  position_history.push_front(target_node.global_position)
  rotation_history.push_front(target_node.global_rotation)

  # デバッグ情報（間隔を空けて出力）
  if Engine.get_process_frames() % 60 == 0:  # 60フレームに1回
    print_debug(
      "TrailFollowSystem [",
      target_node.name,
      "] - Recording rotation: ",
      snapped(rad_to_deg(target_node.global_rotation), 0.1),
      "°, History size: ",
      position_history.size()
    )

  # サイズ制限
  if position_history.size() > history_size:
    position_history.pop_back()
    rotation_history.pop_back()


func get_position_at_delay(delay_frames: int) -> Vector2:
  """指定フレーム数前の位置を取得"""
  delay_frames = max(0, delay_frames)
  var index = min(delay_frames, position_history.size() - 1)

  if position_history.is_empty():
    return target_node.global_position if target_node else Vector2.ZERO

  return position_history[index]


func get_rotation_at_delay(delay_frames: int) -> float:
  """指定フレーム数前の回転を取得"""
  delay_frames = max(0, delay_frames)
  var index = min(delay_frames, rotation_history.size() - 1)

  if rotation_history.is_empty():
    return target_node.global_rotation if target_node else 0.0

  return rotation_history[index]


func get_direction_at_delay(delay_frames: int) -> Vector2:
  """指定フレーム数前の移動方向ベクトルを取得"""
  if position_history.size() < 2:
    return Vector2.RIGHT  # デフォルト方向

  var current_index = min(delay_frames, position_history.size() - 1)
  var next_index = min(delay_frames + 1, position_history.size() - 1)

  if current_index == next_index:
    return Vector2.RIGHT

  var direction = (position_history[current_index] - position_history[next_index]).normalized()
  return direction if direction != Vector2.ZERO else Vector2.RIGHT


func get_history_size() -> int:
  """現在の履歴サイズを取得"""
  return position_history.size()


func clear_history():
  """履歴をクリア"""
  position_history.clear()
  rotation_history.clear()
  if target_node:
    _initialize_history()
