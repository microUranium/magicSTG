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


func _ready():
  super._ready()
  if speed > min_speed:
    var tw = get_tree().create_tween()
    tw.tween_property(self, "speed", min_speed, deceleration_time)
    tw.play()


func _process(delta):
  position += direction * speed * delta
  if not PlayArea.get_play_rect().has_point(global_position):
    _create_explosion_effect()
    _handle_particle_cleanup()
    queue_free()

  _moving_distance += speed * delta
  if bullet_range > 0 and _moving_distance >= bullet_range:
    _create_explosion_effect()
    _handle_particle_cleanup()
    queue_free()  # 射程距離に達したら自動的に削除

  _lifetime_timer += delta
  if bullet_lifetime > 0 and _lifetime_timer >= bullet_lifetime:
    _create_explosion_effect()
    _handle_particle_cleanup()
    queue_free()  # 有効時間を超過したら自動的に削除
