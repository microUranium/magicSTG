extends Resource
class_name EnchantmentTier

@export_range(1, 3) var level := 1
@export var modifiers: Dictionary = {"cooldown_pct": 0.0, "damage_add": 0}
