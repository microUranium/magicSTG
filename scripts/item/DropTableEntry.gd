extends Resource
class_name DropTableEntry
@export var prototype: ItemBase  # 落ちる元アイテム
@export var probability: float = 0.05  # 0–1
@export var enchant_rule: EnchantmentRule
