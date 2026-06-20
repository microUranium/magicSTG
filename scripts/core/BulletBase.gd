extends Area2D
class_name BulletBase

@export var target_group: String = "enemies"
@export var damage: int = 1
var penetration_count: int = 0  # 貫通回数 0=貫通なし 1以上=貫通回数 -1=無限貫通
var hit_count: int = 0  # 現在のヒット回数

# === 1F無敵設定 ===
## 生成後1フレームの衝突を無視するか（拡散弾など、生成位置が敵と重なる場合に使用）
var ignore_first_frame_collision: bool = false
var _spawn_frame: int = 0

# === SHOT_ON_HIT 設定 ===
## ヒット時に実行するパターン
var on_hit_pattern: AttackPattern = null
## ヒット位置から発射するか
var on_hit_use_hit_position: bool = true
## 弾1つにつき1回のみ発動
var on_hit_trigger_once: bool = true
## 発動済みフラグ
var _on_hit_triggered: bool = false

# === シグナル ===
## ヒット時パターン発動要求
signal hit_pattern_requested(
  hit_position: Vector2, bullet_position: Vector2, pattern: AttackPattern
)


func _ready():
  _spawn_frame = Engine.get_process_frames()
  connect("area_entered", Callable(self, "_on_area_entered"))
  StageSignals.destroy_bullet.connect(_destroy_bullet)


func _destroy_bullet() -> void:
  """シグナルによる弾の破壊（即座削除）"""
  _immediate_removal()


func _immediate_removal():
  """即座削除（画面外・敵ヒット時）
  ProjectileBullet/UniversalBulletでオーバーライド可能"""
  _create_explosion_effect()
  _handle_particle_cleanup()
  queue_free()


func _handle_particle_cleanup():
  """パーティクルの適切なクリーンアップ処理"""
  # UniversalBulletでオーバーライド予定
  pass


func _create_explosion_effect():
  """爆発エフェクトの生成"""
  # UniversalBulletでオーバーライド予定
  pass


func _on_area_entered(body):
  # フラグが有効な場合のみ、生成後1フレームは衝突判定をスキップ（拡散弾の即ヒット防止）
  if ignore_first_frame_collision and Engine.get_process_frames() - _spawn_frame <= 1:
    return

  if body.is_in_group(target_group):
    body.take_damage(damage)  # 敵側に take_damage 実装がある前提
    hit_count += 1

    # SHOT_ON_HIT パターンの発動
    if on_hit_pattern and (not on_hit_trigger_once or not _on_hit_triggered):
      var hit_pos = (
        body.global_position if body.has_method("get_global_position") else global_position
      )
      hit_pattern_requested.emit(hit_pos, global_position, on_hit_pattern)
      _on_hit_triggered = true

    # 貫通判定
    if penetration_count == 0 or (penetration_count > 0 and hit_count > penetration_count):
      # 敵ヒット時は即座削除（フェードアウトなし）
      _immediate_removal()
