extends Resource
class_name EnchantmentRule
@export_range(0, 3) var max_count := 2
@export var level_weights := {0: 0.7, 1: 0.3, 2: 0, 3: 0}
@export var pool: Array[Enchantment] = []  # 候補
