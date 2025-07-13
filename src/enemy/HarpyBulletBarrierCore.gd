extends AttackCoreBase

@export var bullet_scene: PackedScene
@export var bullet_direction: Vector2 = Vector2.DOWN
@export var target_group: String = "player"
@export var bullet_amount: int = 8 # 弾の数
@export var damage: int = 5

func _ready() -> void:
  show_on_hud = false
  super._ready()

func _do_fire():
  if bullet_scene:
    # バレットグループは "harpy_bullets" + UID
    var bullet_group = "harpy_bullets_" + str(ResourceUID.create_id())
    for i in range(bullet_amount):
      var bullet : HarpyBulletBarrier = bullet_scene.instantiate()
      get_tree().current_scene.add_child(bullet)
      
      bullet.owner_node = _owner_actor
      bullet.bullet_group = bullet_group
      bullet.bullet_amount = bullet_amount
      bullet.bullet_number = i
      bullet.damage = damage

      bullet.start()
      
      bullet.target_group = target_group