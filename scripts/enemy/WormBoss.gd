extends EnemyBase
class_name WormBoss

# ワームボス統合クラス
# 頭部の動作とSegmentManagerを統合管理

# ワーム設定
@export var segment_count: int = 6
@export var segment_spacing: float = 20.0
@export var enable_debug_draw: bool = false

# 内部コンポーネント
@onready var ai: WormBossAI = $EnemyAI
@onready var hp_node: Node = $HpNode
var segment_manager: WormSegmentManager
var trail_system: TrailFollowSystem

# 状態管理
var is_worm_initialized: bool = false


func setup():
  """初期化処理"""
  # WormSegmentManagerを作成・設定
  _setup_segment_manager()
  # TrailFollowSystemを追加
  _setup_trail_system()
  # ワームシステムを初期化
  _initialize_worm_system()


func _setup_segment_manager():
  """WormSegmentManagerの設定"""
  segment_manager = WormSegmentManager.new()
  segment_manager.name = "WormSegmentManager"
  segment_manager.segment_count = segment_count
  segment_manager.segment_spacing = segment_spacing
  segment_manager.debug_draw_connections = enable_debug_draw

  # シーンに追加
  get_tree().current_scene.add_child(segment_manager)


func _setup_trail_system():
  """TrailFollowSystemの設定"""
  trail_system = TrailFollowSystem.new()
  trail_system.name = "TrailFollowSystem"
  trail_system.history_size = 15  # 長めの履歴を保持
  add_child(trail_system)


func _initialize_worm_system():
  """ワームシステム全体の初期化"""
  if not segment_manager:
    push_error("WormBoss: セグメントマネージャーが見つかりません")
    return

  # セグメントマネージャーを初期化
  segment_manager.setup(self)

  is_worm_initialized = true


func take_damage(amount: int) -> void:
  """ダメージ処理のオーバーライド"""
  super.take_damage(amount)

  # ダメージ時のエフェクトを全ての節に適用可能
  _flash_all_segments()


func _flash_all_segments():
  """全ての節をフラッシュ"""
  if not segment_manager:
    return

  for segment in segment_manager.get_all_segments():
    if segment and is_instance_valid(segment):
      var sprite = segment.get_node("AnimatedSprite2D")
      if sprite:
        FlashUtility.flash_white(sprite)


func _process(delta):
  # ワームシステムの状態チェック
  if is_worm_initialized and segment_manager:
    _check_segment_health()


func _check_segment_health():
  """節の健全性チェック"""
  if not segment_manager.are_segments_following_properly():
    print_debug("WormBoss: 一部の節が正常に追従していません")
    # 必要に応じて修復処理を実装可能


func get_segment_count() -> int:
  """現在の節数を取得"""
  return segment_manager.get_segment_count() if segment_manager else 0


func get_all_worm_nodes() -> Array[Node]:
  """ワーム全体（頭部 + 全ての節）を取得"""
  var nodes: Array[Node] = [self]

  if segment_manager:
    for segment in segment_manager.get_all_segments():
      if segment and is_instance_valid(segment):
        nodes.append(segment)

  return nodes


func set_worm_segment_spacing(spacing: float):
  """ワーム全体の節間距離を設定"""
  segment_spacing = spacing
  if segment_manager:
    segment_manager.set_segment_spacing_all(spacing)


func add_segment():
  """動的に節を追加"""
  if segment_manager:
    segment_manager.add_segment_at_end()
    print_debug("WormBoss: 節を追加")


func remove_segment():
  """動的に節を削除"""
  if segment_manager:
    segment_manager.remove_last_segment()
    print_debug("WormBoss: 節を削除")


func _exit_tree():
  """終了時のクリーンアップ"""
  if segment_manager and is_instance_valid(segment_manager):
    segment_manager.cleanup()
    segment_manager.queue_free()


# デバッグ用メソッド
func toggle_debug_draw():
  """デバッグ描画の切り替え"""
  enable_debug_draw = not enable_debug_draw
  if segment_manager:
    segment_manager.debug_draw_connections = enable_debug_draw


func get_worm_info() -> Dictionary:
  """ワーム情報の取得（デバッグ用）"""
  return {
    "segment_count": get_segment_count(),
    "segment_spacing": segment_spacing,
    "is_initialized": is_worm_initialized,
    "head_position": global_position,
    "segments_following":
    segment_manager.are_segments_following_properly() if segment_manager else false
  }
