extends Resource
class_name EnchantmentRule

@export var count_weights := {0: 0.6, 1: 0.3, 2: 0.1, 3: 0.0}  # 上限は LootSystem.enchantment_max_count
@export var level_weights := {1: 1, 2: 0, 3: 0}
@export var pool: Array[Enchantment] = []  # 候補
