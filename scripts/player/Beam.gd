extends Area2D

@export var damage: int = 1
@export var desired_length: float = 1000.0
@export var owner_path: NodePath  # 精霊への参照
@export var enemy_group: String = "enemies"
@export var damage_tick_sec: float = 1.0 / 30.0

const MAX_RAYCAST_SKIPS := 32  # 敵を探すときに読み飛ばす敵以外（弾など）の上限

var owner_node: Node2D
var _hit_enemy: Node = null  # ビームの線上で最も手前にいる敵（いなければ null）
var _hit_point: Vector2 = Vector2.ZERO

@onready var ninepatch: NinePatchRect = $NinePatchRect
@onready var shape: RectangleShape2D = $CollisionShape2D.shape
@onready var raycast: RayCast2D = $RayCast2D
@onready var dmg_timer: Timer = $DamageTimer


func _ready():
  raycast.target_position = Vector2(0, -desired_length)
  raycast.enabled = true
  raycast.exclude_parent = true

  dmg_timer.wait_time = damage_tick_sec
  dmg_timer.timeout.connect(_on_damage_tick)
  dmg_timer.start()

  _apply_length(desired_length)

  if owner_path != NodePath():
    owner_node = get_node(owner_path)


func initialize(
  _owner_node: Node2D, _damage: int, _beam_direction: Vector2, _offset: Vector2 = Vector2.ZERO
) -> void:
  """ビームの初期化"""
  # _offset は UniversalAttackCore が UniversalBeam と同じ引数で呼ぶために受け取るだけで使わない。
  # プレイヤー用パターンの beam_offset は既定値 (0, 50) のため、適用すると精霊から下にずれる。
  self.owner_node = _owner_node
  self.damage = _damage
  rotation = _beam_direction.angle() + deg_to_rad(90)  # 上向きが0度なので調整


func _process(_delta: float) -> void:
  if owner_node:
    global_position = owner_node.global_position

  _update_hit()
  var length := desired_length
  if _hit_enemy:
    length = global_position.distance_to(_hit_point)

  _apply_length(length)


## ビームの線上で最も手前にいる敵を探す。
## RayCast2D のマスク（レイヤー2）には敵だけでなく弾（自弾・敵弾）もいるため、
## 敵以外に当たったら除外して同じ線を調べ直す。最初の当たりで打ち切ると、
## 手前を弾が横切った瞬間にビームが敵をすり抜け、ダメージも出なくなる。
func _update_hit() -> void:
  _hit_enemy = null
  raycast.clear_exceptions()
  for _i in MAX_RAYCAST_SKIPS:
    raycast.force_raycast_update()
    if not raycast.is_colliding():
      break
    var col := raycast.get_collider()
    if col and col.is_in_group(enemy_group):
      _hit_enemy = col
      _hit_point = raycast.get_collision_point()
      break
    if col is CollisionObject2D:
      raycast.add_exception(col)
    else:
      break  # 除外できない相手（タイルマップ等）はそこで打ち切る
  raycast.clear_exceptions()


func _apply_length(length: float) -> void:
  # 視覚
  ninepatch.size.y = length
  ninepatch.position.y = -length
  # コリジョン
  shape.extents.y = length * 0.5
  $CollisionShape2D.position.y = -length * 0.5


func _on_damage_tick() -> void:
  StageSignals.sfx_play_requested.emit("shot_beam", global_position, 0, 1.0)
  if not is_instance_valid(_hit_enemy) or not _hit_enemy.is_in_group(enemy_group):
    return

  if _hit_enemy.has_method("take_damage"):
    _hit_enemy.take_damage(_resolve_damage(_hit_enemy))


## 弾（BulletBase._resolve_damage）と同じく、プレイヤーの加護（近接・背水など）の与ダメージ補正を乗せる
func _resolve_damage(enemy: Node) -> int:
  var player = TargetService.get_player()
  if is_instance_valid(player) and "blessing_container" in player and player.blessing_container:
    return player.blessing_container.process_outgoing_damage(enemy, damage)
  return damage
