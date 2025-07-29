extends AttackCoreBase

@export var bullet_direction: Vector2 = Vector2.UP
@export var target_group: String = "enemies"

var _bullet_speed := 400.0


func _ready() -> void:
  super._ready()

  # 汎用ゲージの初期化
  init_gauge("cooldown", 100, 0, _proto.display_name)


func _process(_delta: float) -> void:
  if _cool_timer:
    var elapsed = _cool_timer.time_left
    set_gauge((cooldown_sec - elapsed) * 100 / cooldown_sec)  # 残り時間をゲージに反映


func _do_fire() -> bool:
  if _proto.projectile_scene:
    set_gauge(0)  # 発射時にゲージをリセット
    var parent := _find_bullet_parent()
    if parent == null:
      push_warning("ProjectileCore: No valid parent node found, aborting fire.")
      return false

    var bullet = _proto.projectile_scene.instantiate()
    parent.add_child(bullet)

    bullet.speed = _bullet_speed
    bullet.damage = int(_proto.damage_base * (1.0 + _sum_pct("damage_pct")))
    bullet.direction = bullet_direction
    bullet.target_group = target_group

    if _owner_actor:
      bullet.global_position = _owner_actor.global_position  # 親はSpirit
    else:
      push_warning("ProjectileCore: Owner actor is not set. Using default position.")

    return true

  return false


func _on_stats_updated() -> void:
  # アイテム基礎 + エンチャントを反映
  _bullet_speed = _proto.base_modifiers.bullet_speed * (1.0 + _sum_pct("bullet_speed_pct"))
