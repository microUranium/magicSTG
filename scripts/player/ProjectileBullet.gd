extends BulletBase
class_name ProjectileBullet

@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.UP
@export var deceleration_time: float = 3  # 速度減衰時間
@export var min_speed: float = 500.0  # 最低速度
@export var bullet_range: float = 0.0  # 弾丸の射程距離 0なら無限
@export var bullet_lifetime: float = 0.0  # 弾丸の有効時間 0なら無限

var _moving_distance: float = 0.0  # 移動距離の累積
var _lifetime_timer: float = 0.0  # 生存時間の累積

# 画面外でも消えない設定
var persist_offscreen: bool = false
var max_offscreen_distance: float = 2000.0
var forced_lifetime: float = 30.0
var _spawn_position: Vector2 = Vector2.ZERO
var _forced_lifetime_timer: float = 0.0


func _ready():
  super._ready()
  _spawn_position = global_position  # 発射位置を記録
  if speed > min_speed:
    var tw = get_tree().create_tween()
    tw.tween_property(self, "speed", min_speed, deceleration_time)
    tw.play()


func _process(delta):
  # === 移動処理 ===
  position += direction * speed * delta

  # === 安全機構1: 強制削除タイマー（最優先） ===
  if persist_offscreen:
    _forced_lifetime_timer += delta
    if _forced_lifetime_timer >= forced_lifetime:
      queue_free()
      return

  # === 安全機構2: 画面外チェック ===
  var play_rect = PlayArea.get_play_rect()
  var is_onscreen = play_rect.has_point(global_position)

  if not is_onscreen:
    if not persist_offscreen:
      # 通常の削除
      _create_explosion_effect()
      _handle_particle_cleanup()
      queue_free()
      return
    else:
      # 距離制限チェック
      var distance = global_position.distance_to(_spawn_position)
      if distance > max_offscreen_distance:
        queue_free()
        return

  # === 既存の削除条件（射程・寿命） ===
  _moving_distance += speed * delta
  if bullet_range > 0 and _moving_distance >= bullet_range:
    _create_explosion_effect()
    _handle_particle_cleanup()
    queue_free()
    return

  _lifetime_timer += delta
  if bullet_lifetime > 0 and _lifetime_timer >= bullet_lifetime:
    _create_explosion_effect()
    _handle_particle_cleanup()
    queue_free()
    return
