extends Resource
class_name Enchantment

@export var id: StringName  # 一意識別子
@export var display_name: String  # 表示名
@export_multiline var description: String  # 説明
@export var tiers: Array[EnchantmentTier] = []


func get_tier(level: int) -> EnchantmentTier:
  # レベルが範囲外なら端にクランプ
  for t in tiers:
    if t.level == level:
      return t
  return tiers.back() if level > tiers.back().level else tiers.front()


func get_modifiers(level: int) -> Dictionary:
  return get_tier(level).modifiers.duplicate()
