extends EnemyAIBase
class_name CounterAttackAI

@export var counter_sfx: String = "hit_wood"


func _ready():
  super._ready()

  if enemy_node:
    enemy_node.connect("received_damage", _on_received_damage)


func _on_received_damage(amount: int, isInvincible: bool):
  if is_instance_valid(attack_core_slot):
    StageSignals.emit_signal("sfx_play_requested", counter_sfx, Vector2.ZERO, 0, 0)
    attack_core_slot.trigger_all_cores()
