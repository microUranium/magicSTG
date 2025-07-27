extends Node

var _rng := RandomNumberGenerator.new()
const enchantment_max_count := 2  # 最大エンチャント数


# -------------------------------------------------
# Public API
# -------------------------------------------------
func spawn_drop(pos: Vector2, drop_table: Array[DropTableEntry]) -> void:
  for entry in drop_table:
    if _rng.randf() <= entry.probability:
      var inst := ItemInstance.new(entry.prototype)
      _roll_enchantments(inst, entry.enchant_rule)
      _spawn_item_node(pos, inst)


# -------------------------------------------------
# Private Methods
# -------------------------------------------------
func _roll_enchantments(inst: ItemInstance, rule: EnchantmentRule) -> void:
  if rule == null or rule.pool.is_empty():
    return
  var count: int = min(enchantment_max_count, int(_weighted_pick(rule.count_weights)))
  var table = rule.pool.duplicate()
  for i in count:
    if table.is_empty():
      break  # No more enchantments to pick
    var enc: Enchantment = table.pick_random()
    table.erase(enc)  # Remove to avoid duplicates
    var level: int = _weighted_pick(rule.level_weights)
    var enc_copy := enc.duplicate()
    inst.add_enchantment(enc_copy, level)


func _spawn_item_node(pos: Vector2, inst: ItemInstance) -> void:
  var scene := preload("res://scenes/items/dropped_item.tscn")
  var node := scene.instantiate()
  if not node is DroppedItem:
    push_error("Spawned node is not a DroppedItem instance.")
    return
  node.global_position = pos
  node.item_instance = inst
  get_tree().current_scene.add_child(node)


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
