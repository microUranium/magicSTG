extends Resource
class_name ItemBase

enum ItemType { BLESSING, ATTACK_CORE }

@export var id: StringName  # アイテムの一意識別子
@export var item_type: ItemType  # アイテムの種類[BLESSING, ATTACK_CORE]
@export var display_name: String  # アイテムの表示名
@export_multiline var description: String  # アイテムの説明
@export var icon: Texture2D  # アイテムのアイコン
## ドロップ時に付与されうるエンチャント。空なら制限なし（EnchantmentRule.pool をそのまま使う）
@export var allowed_enchantments: Array[Enchantment] = []


func allows_enchantment(enc: Enchantment) -> bool:
  if enc == null:
    return false
  if allowed_enchantments.is_empty():
    return true
  # pool 側が duplicate() された別インスタンスでも一致するよう id で比較する
  for allowed in allowed_enchantments:
    if allowed and allowed.id == enc.id:
      return true
  return false
