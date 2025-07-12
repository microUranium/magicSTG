extends AttackCoreBase

@export var bullet_scene: PackedScene
@export var bullet_direction: Vector2 = Vector2.DOWN
@export var target_group: String = "player"
@export var bullet_amount: int = 8 # 弾の数
@export var damage: int = 5
@export var bullet_circle_radius: Array = [100, 140]

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

    for i in range(bullet_circle_radius.size()):
      # バレットグループは "harpy_bullets" + UID
      var bullet_group = "harpy_bullets_" + str(ResourceUID.create_id())
      for j in range(bullet_amount):
        var bullet : HarpyBulletBarrier = bullet_scene.instantiate()
        get_tree().current_scene.add_child(bullet)
        
        bullet.owner_node = _owner_actor
        bullet.bullet_group = bullet_group
        bullet.bullet_amount = bullet_amount
        bullet.bullet_number = j
        bullet.target_node = player
        bullet.circle_radius = bullet_circle_radius[i]
        bullet.damage = damage
        
        bullet.target_group = target_group

        bullet.start()

      await get_tree().create_timer(0.5).timeout