extends EnemyBase
class_name EnemyLivingWood

@export var shield_scene: PackedScene = preload("res://scenes/enemy/enemy_living_wood_shield.tscn")
@export var shield_amount: int = 1
var shield_instances: Array[Node2D]


func _ready():
  super._ready()
  shield_instances = _create_shields(shield_amount)


func _create_shields(amount: int) -> Array[Node2D]:
  if shield_scene:
    var shields: Array[Node2D] = []
    for i in amount:
      var shield = shield_scene.instantiate()
      add_child(shield)
      if shield and shield is EnemyLivingWoodShield:
        shield.set_owner_node(self)

        # Set initial angle for equal distribution around circle
        var orbit_ai = shield.get_node("EnemyAI")
        if orbit_ai and orbit_ai is OrbitAI:
          var initial_angle = (2.0 * PI * i) / amount
          orbit_ai.set_initial_angle(initial_angle)

      shield.position = Vector2(0, 0)
      shields.append(shield)
    return shields
  return []


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if current_hp <= 0:
    _spawn_destroy_particles()
    _drop_item()
    StageSignals.emit_signal("sfx_play_requested", "destroy_enemy", global_position, 0, 0)
    for shield_instance in shield_instances:
      if shield_instance and shield_instance.is_inside_tree():
        shield_instance.queue_free()
    queue_free()
