extends RefCounted
class_name ItemInstance

signal enchantment_added(enchant: Enchantment, level: int)

var uid: String = ""  # ユニークID
var prototype: ItemBase
var enchantments: Dictionary[Enchantment, int] = {}  # enchant: level

# --- 互換用ダミー ---
## 将来の Stack 実装時、
## ここを virtual に置き換える or override する想定。
const _DUMMY_QUANTITY := 1


func get_quantity() -> int:  # 読み取り専用
  return _DUMMY_QUANTITY


# -------------------


func _init(p: ItemBase, _uid: String = "") -> void:
  prototype = p
  if _uid == "":
    uid = ResourceUID.id_to_text(ResourceUID.create_id())
  else:
    uid = _uid  # 外部から指定された場合はそのまま使用


func add_enchantment(enc: Enchantment, level: int) -> void:
  enchantments.set(enc, level)
  emit_signal("enchantment_added", enc, level)
