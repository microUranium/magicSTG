extends EnemyAIBase

@export var align_speed: float = 400.0  # 整列移動速度
@export var stop_threshold: float = 2.0  # 到達判定距離
@export var row_height: float = 160.0  # 画面上からの Y 位置
@export var lock_delay: float = 1.0  # (秒) 目標を固定するまでの最大猶予（安全上限）
@export var stabilize_time: float = 0.25  # (秒) グループの増加が止まってから目標を固定するまでの猶予

var _row_y: float  # 整列行の Y
var _target_pos: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _target_locked: bool = false
var _seen_max: int = 0  # これまでに観測したグループ最大数（単調増加。撃破で減らさない）
var _stable_elapsed: float = 0.0  # グループが増加しなくなってからの経過時間


func _ready():
  super()  # EnemyAIBase _ready()
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
  # 1) グループが増えている間だけ等間隔を再計算し、増加が止まったら固定
  #    ・total は観測した最大数(_seen_max)を使うため、撃破で数が減っても
  #      再計算されず、確定済みの座標が動かない。
  #    ・出現直後の数フレームで敵が出揃った後は _seen_max が増えなくなり、
  #      stabilize_time 経過で固定される（撃破前に座標が確定する）。
  # ------------------------------------------------------------
  if not _target_locked:
    _elapsed += delta
    var count := get_tree().get_nodes_in_group("line_horiz_enemies").size()
    if count > _seen_max:
      _seen_max = count
      _stable_elapsed = 0.0
      _recalc_target_pos()  # 増加時のみ再計算（このとき生存数 == _seen_max）
    else:
      _stable_elapsed += delta

    if _stable_elapsed >= stabilize_time or _elapsed >= lock_delay:
      _target_locked = true  # 以後は _target_pos を維持する

  # ------------------------------------------------------------
  # 2) 目標へ移動（move_toward で行き過ぎを防ぎ、到達時は正確にスナップ）
  # ------------------------------------------------------------
  if enemy_node.global_position.distance_to(_target_pos) > stop_threshold:
    enemy_node.global_position = enemy_node.global_position.move_toward(
      _target_pos, align_speed * delta
    )
  else:
    # 整列完了後の追加行動をここに記述
    pass


#-----------------------------------------------------------------
# Helper : 等間隔で target_pos を算出
#-----------------------------------------------------------------
func _recalc_target_pos() -> void:
  var group := get_tree().get_nodes_in_group("line_horiz_enemies")
  group.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())

  var index: int = group.find(enemy_node)
  var total: int = _seen_max  # 単調増加の最大数。撃破で減らないため座標が確定する

  var rect := PlayArea.get_play_rect()
  var spacing: float = rect.size.x / (total + 1)  # 左端～右端を N+1 分割
  var target_x := rect.position.x + spacing * (index + 1)

  _target_pos = Vector2(target_x, _row_y)
