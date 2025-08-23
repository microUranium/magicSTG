extends RefCounted
class_name ItemInstance

signal enchantment_added(enchant: Enchantment, level: int)

enum RarityTier { NORMAL = 0, COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4, LEGENDARY = 5 }  # 0: 灰色  # 1,2: 緑色  # 3,4: 青色  # 5,6: 紫色  # 7,8: 黄色  # 9+: 赤色

const RARITY_COLORS = {
  RarityTier.NORMAL: Color("#808080"),  # 灰色
  RarityTier.COMMON: Color("#45A356"),  # 緑色
  RarityTier.UNCOMMON: Color("#457AA3"),  # 青色
  RarityTier.RARE: Color("#8528C0"),  # 紫色
  RarityTier.EPIC: Color("#C49824"),  # 黄色（ゴールド）
  RarityTier.LEGENDARY: Color("#D3153E")  # 赤色
}

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


func get_rarity_level() -> int:
  var total_level = 0
  for enchantment in enchantments:
    total_level += enchantments[enchantment]
  return total_level


func get_rarity_tier() -> RarityTier:
  var level = get_rarity_level()
  match level:
    0:
      return RarityTier.NORMAL
    1, 2:
      return RarityTier.COMMON
    3, 4:
      return RarityTier.UNCOMMON
    5, 6:
      return RarityTier.RARE
    7, 8:
      return RarityTier.EPIC
    _:
      return RarityTier.LEGENDARY


func get_rarity_color() -> Color:
  return RARITY_COLORS.get(get_rarity_tier(), Color.WHITE)
