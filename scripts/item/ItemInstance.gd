extends RefCounted
class_name ItemInstance

signal enchantment_added(enchant: Enchantment)

var prototype: ItemBase
var enchantments: Array[Enchantment] = []

# --- 互換用ダミー ---
## 将来の Stack 実装時、
## ここを virtual に置き換える or override する想定。
const _DUMMY_QUANTITY := 1


func get_quantity() -> int:  # 読み取り専用
  return _DUMMY_QUANTITY


# -------------------


func _init(p: ItemBase) -> void:
  prototype = p


func add_enchantment(enc: Enchantment) -> void:
  enchantments.append(enc)
  emit_signal("enchantment_added", enc)
