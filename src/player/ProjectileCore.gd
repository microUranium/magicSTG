extends AttackCoreBase

@export var bullet_scene: PackedScene
@export var bullet_direction: Vector2 = Vector2.UP
@export var target_group: String = "enemies"


func _ready() -> void:
  super._ready()

  # 汎用ゲージの初期化
  init_gauge("cooldown", 100, 0, "魔弾")

func _process(_delta: float) -> void:
  if _cool_timer:
    var elapsed = _cool_timer.time_left
    set_gauge((cooldown_sec - elapsed) * 100 / cooldown_sec)  # 残り時間をゲージに反映

func _do_fire():
  if bullet_scene:
    set_gauge(0)  # 発射時にゲージをリセット
    var bullet = bullet_scene.instantiate()
    get_tree().current_scene.add_child(bullet)

    if _owner_actor:
      bullet.global_position = _owner_actor.global_position # 親はSpirit
    else:
      push_warning("ProjectileCore: Owner actor is not set. Using default position.")

    bullet.direction = bullet_direction
    bullet.target_group = target_group
