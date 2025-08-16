extends Node2D
class_name WormSegmentManager

# ワーム節の一元管理システム
# 節の生成、削除、更新を管理

# 設定パラメータ
@export var segment_count: int = 8  # 節の数
@export var segment_spacing: float = 18.0  # 節間距離
@export var base_delay_frames: int = 4  # 基本追従遅延フレーム数
@export var delay_increment: int = 1  # 各節の遅延増加量

# シーン参照
@export var segment_scene: PackedScene  # 節のシーンファイル

# 管理データ
var segments: Array[WormSegment] = []
var head_node: Node2D  # 頭部ノード（WormBoss）
var is_initialized: bool = false

# デバッグ用
@export var debug_draw_connections: bool = false


func _ready():
  # デフォルトシーンの設定
  if not segment_scene:
    segment_scene = preload("res://scenes/enemy/enemy_boss_snake_body.tscn")


func setup(head: Node2D):
  """ワームマネージャーの初期設定"""
  head_node = head

  if not head_node:
    push_error("WormSegmentManager: 頭部ノードが指定されていません")
    return

  # 頭部にTrailFollowSystemを追加
  _ensure_head_has_trail_system()

  # 節を生成
  _create_segments()

  is_initialized = true
  print_debug("WormSegmentManager initialized with ", segment_count, " segments")


func _ensure_head_has_trail_system():
  """頭部にTrailFollowSystemがあることを確認"""
  var trail_system = head_node.get_node("TrailFollowSystem")
  if not trail_system:
    trail_system = TrailFollowSystem.new()
    trail_system.name = "TrailFollowSystem"
    head_node.add_child(trail_system)
    print_debug("WormSegmentManager: 頭部にTrailFollowSystemを追加")


func _create_segments():
  """全ての節を生成"""
  if not segment_scene:
    push_error("WormSegmentManager: 節シーンが設定されていません")
    return

  var previous_node = head_node

  for i in range(segment_count):
    var segment = _create_single_segment(i, previous_node)
    if segment:
      segments.append(segment)
      previous_node = segment
    else:
      push_warning("WormSegmentManager: 節 ", i, " の生成に失敗")


func _create_single_segment(index: int, prev_node: Node2D) -> WormSegment:
  """単一の節を生成"""
  _ensure_node_has_trail_system(prev_node)

  var segment_instance = segment_scene.instantiate()

  if not segment_instance:
    push_error("WormSegmentManager: 節シーンのインスタンス化に失敗")
    return null

  # スクリプトを適用
  if not segment_instance.has_method("setup"):
    segment_instance.set_script(preload("res://scripts/enemy/WormSegment.gd"))

  # 節をシーンに追加
  get_tree().current_scene.add_child(segment_instance)

  # 追従遅延の計算（後ろの節ほど遅延が大きい）
  var delay = base_delay_frames + (index * delay_increment)

  # 節の設定（TrailFollowSystem追加後に実行）
  segment_instance.setup(prev_node, head_node, delay)
  segment_instance.set_segment_spacing(segment_spacing)

  # 初期位置設定
  _position_segment_initially(segment_instance, prev_node, index)

  print_debug("WormSegmentManager: 節 ", index, " を生成（遅延: ", delay, "）")
  return segment_instance


func _ensure_node_has_trail_system(node: Node2D):
  """ノードにTrailFollowSystemがあることを確認"""
  var existing_trail = node.get_node("TrailFollowSystem")
  if not existing_trail:
    var trail_system = TrailFollowSystem.new()
    trail_system.name = "TrailFollowSystem"
    node.add_child(trail_system)
    print_debug("WormSegmentManager: TrailFollowSystemを追加しました - ", node.name)
  else:
    print_debug("WormSegmentManager: TrailFollowSystemは既に存在 - ", node.name)


func _position_segment_initially(segment: WormSegment, prev_node: Node2D, index: int):
  """節の初期位置を設定"""
  if prev_node:
    # 前の節から適切な距離で配置
    var offset_direction = Vector2(-1, 0)  # 後方方向
    if prev_node.has_method("get_current_facing_direction"):
      offset_direction = -prev_node.get_current_facing_direction()
    elif prev_node.global_rotation != 0:
      offset_direction = Vector2(-cos(prev_node.global_rotation), -sin(prev_node.global_rotation))

    segment.global_position = prev_node.global_position + offset_direction * segment_spacing
    segment.global_rotation = prev_node.global_rotation


func _draw():
  """デバッグ用：節間の接続を描画"""
  if not debug_draw_connections or not is_initialized:
    return

  # 頭部から最初の節への線
  if segments.size() > 0 and head_node:
    var local_head_pos = to_local(head_node.global_position)
    var local_first_segment_pos = to_local(segments[0].global_position)
    draw_line(local_head_pos, local_first_segment_pos, Color.YELLOW, 2.0)

  # 節間の接続線
  for i in range(segments.size() - 1):
    if segments[i] and segments[i + 1]:
      var pos1 = to_local(segments[i].global_position)
      var pos2 = to_local(segments[i + 1].global_position)
      draw_line(pos1, pos2, Color.RED, 2.0)


func add_segment_at_end() -> WormSegment:
  """末尾に新しい節を追加"""
  if segments.is_empty():
    push_warning("WormSegmentManager: 既存の節が存在しません")
    return null

  var last_segment = segments[-1]
  var new_segment = _create_single_segment(segments.size(), last_segment)

  if new_segment:
    segments.append(new_segment)
    print_debug("WormSegmentManager: 節を末尾に追加")

  return new_segment


func remove_last_segment():
  """末尾の節を削除"""
  if segments.is_empty():
    return

  var last_segment = segments.pop_back()
  if last_segment and is_instance_valid(last_segment):
    last_segment.queue_free()
    print_debug("WormSegmentManager: 末尾の節を削除")


func get_segment_count() -> int:
  """現在の節数を取得"""
  return segments.size()


func get_segment_at(index: int) -> WormSegment:
  """指定インデックスの節を取得"""
  if index >= 0 and index < segments.size():
    return segments[index]
  return null


func get_all_segments() -> Array[WormSegment]:
  """全ての節を取得"""
  return segments.duplicate()


func cleanup():
  """全ての節を削除"""
  for segment in segments:
    if segment and is_instance_valid(segment):
      segment.queue_free()

  segments.clear()
  is_initialized = false
  print_debug("WormSegmentManager: 全ての節を削除")


func set_segment_spacing_all(spacing: float):
  """全ての節の間隔を設定"""
  segment_spacing = spacing

  for segment in segments:
    if segment and is_instance_valid(segment):
      segment.set_segment_spacing(spacing)


func are_segments_following_properly() -> bool:
  """全ての節が正常に追従しているかチェック"""
  for segment in segments:
    if segment and is_instance_valid(segment):
      if not segment.is_following_properly():
        return false
  return true
