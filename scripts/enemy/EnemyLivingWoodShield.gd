extends EnemyBase
class_name EnemyLivingWoodShield


func _ready():
  super._ready()


func set_owner_node(node: Node2D):
  if node:
    var orbit_ai = $EnemyAI
    if orbit_ai and orbit_ai is OrbitAI:
      orbit_ai.set_owner_node(node)
