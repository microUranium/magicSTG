extends AttackCoreBase

@export var bullet_scene: PackedScene
@export var bullet_direction: Vector2 = Vector2.DOWN
@export var target_group: String = "player"
@export var rapid_fire_amount: int = 1  # 連射数
@export var rapid_fire_delay: float = 0.1  # 連射間隔


func _ready() -> void:
  show_on_hud = false
  super._ready()


func _do_fire():
  var player = get_tree().current_scene.get_node("Player")
  if player and bullet_scene:
    if _owner_actor:
      bullet_direction = (player.global_position - _owner_actor.global_position).normalized()
    else:
      push_warning("EnemyProjectileCore: Owner actor is not set. Using default direction.")

    # 連射処理
    for i in range(rapid_fire_amount):
      var parent := _find_bullet_parent()
      if parent == null:
        push_warning("ProjectileCore: No valid parent node found, aborting fire.")
        return

      var bullet = bullet_scene.instantiate()
      parent.add_child(bullet)

      if _owner_actor:
        bullet.global_position = _owner_actor.global_position  # 親はSpirit
      else:
        push_warning("EnemyProjectileCore: Owner actor is not set. Using default position.")

      bullet.direction = bullet_direction

      bullet.target_group = target_group

      await get_tree().create_timer(rapid_fire_delay).timeout
