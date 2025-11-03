extends EnemyAIBase
class_name OnDestroyAttackAI


func _ready():
  super._ready()

  if enemy_node:
    enemy_node.connect("destroyed", _on_destroyed)


func _on_destroyed():
  if is_instance_valid(attack_core_slot):
    attack_core_slot.trigger_all_cores()
