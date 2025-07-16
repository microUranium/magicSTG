extends Node

var _rng := RandomNumberGenerator.new()


# -------------------------------------------------
func spawn_drop(pos: Vector2, drop_table: Array[DropTableEntry]) -> void:
  for entry in drop_table:
    if _rng.randf() <= entry.probability:
      var inst := ItemInstance.new(entry.prototype)
      _roll_enchantments(inst, entry.enchant_rule)
      _spawn_item_node(pos, inst)


# -------------------------------------------------
func _roll_enchantments(inst: ItemInstance, rule: EnchantmentRule) -> void:
  if rule == null or rule.pool.is_empty():
    return
  var count: int = min(rule.max_count, int(_weighted_pick({0: 0.6, 1: 0.3, 2: 0.09, 3: 0.01})))
  for i in count:
    var enc: Enchantment = rule.pool.pick_random()
    var level: int = _weighted_pick(rule.level_weights)
    var enc_copy := enc.duplicate()
    enc_copy.modifiers["level"] = level
    inst.add_enchantment(enc_copy)


# -------------------------------------------------
func _spawn_item_node(pos: Vector2, inst: ItemInstance) -> void:
  var scene := preload("res://scenes/items/dropped_item.tscn")
  var node := scene.instantiate()
  node.global_position = pos
  node.item_instance = inst  # export var
  get_tree().current_scene.add_child(node)


# -------------------------------------------------
func _weighted_pick(weights: Dictionary) -> Variant:
  var total := 0.0
  for v in weights.values():
    total += v
  var roll := _rng.randf() * total
  var accum := 0.0
  for key in weights.keys():
    accum += weights[key]
    if roll <= accum:
      return key
  return weights.keys()[0]
