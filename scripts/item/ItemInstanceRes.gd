extends Resource
class_name ItemInstanceRes
@export var prototype: ItemBase
@export var enchantments: Array[Enchantment] = []


## 検証・装備時に呼び出して実体化
func to_instance() -> ItemInstance:
  var inst := ItemInstance.new(prototype)
  for enc in enchantments:
    inst.add_enchantment(enc)
  return inst
