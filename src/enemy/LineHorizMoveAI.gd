extends "res://src/core/EnemyAIBase.gd"

@export var align_speed   : float = 400.0   # 整列移動速度
@export var stop_threshold: float = 2.0     # 到達判定距離
@export var row_height       : float = 160.0      # 画面上からの Y 位置
@export var lock_delay    : float = 1.0   # (秒) 目標を固定するまでの猶予

var _row_y      : float                    # 整列行の Y
var _target_pos : Vector2 = Vector2.ZERO
var _elapsed      : float = 0.0
var _target_locked: bool  = false

func _ready():
  super()                                  # EnemyAIBase _ready()
  if enemy_node == null:
    return

  # 整列用グループ登録
  enemy_node.add_to_group("line_horiz_enemies")

  # 整列行 (Y) = スポーン時の Y 座標
  call_deferred("_set_row_y")

func _set_row_y() -> void:
  _row_y = enemy_node.global_position.y

func _process(delta: float) -> void:

  # ------------------------------------------------------------
  # 1) 1 秒以内は等間隔をリアルタイム計算、以降は固定
  # ------------------------------------------------------------
  if not _target_locked:
    _elapsed += delta
    _recalc_target_pos()
    if _elapsed >= lock_delay:
      _target_locked = true     # 以後は _target_pos を維持する

  # ------------------------------------------------------------
  # 2) 目標へ移動
  # ------------------------------------------------------------
  var dir  := _target_pos - enemy_node.global_position
  var dist := dir.length()

  if dist > stop_threshold:
    enemy_node.global_position += dir.normalized() * align_speed * delta
  else:
    # 整列完了後の追加行動をここに記述
    pass

#-----------------------------------------------------------------
# Helper : 等間隔で target_pos を算出
#-----------------------------------------------------------------
func _recalc_target_pos() -> void:
  var group := get_tree().get_nodes_in_group("line_horiz_enemies")
  group.sort_custom(func(a,b): return a.get_instance_id() < b.get_instance_id())

  var index : int = group.find(enemy_node)
  var total : int = group.size()

  var rect   := PlayArea.get_play_rect()
  var spacing: float = rect.size.x / (total + 1)       # 左端～右端を N+1 分割
  var target_x := rect.position.x + spacing * (index + 1)

  _target_pos = Vector2(target_x, _row_y)