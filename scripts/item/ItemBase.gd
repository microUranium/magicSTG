extends Resource
class_name ItemBase

enum ItemType { BLESSING, ATTACK_CORE }

@export var id: StringName  # アイテムの一意識別子
@export var item_type: ItemType  # アイテムの種類[BLESSING, ATTACK_CORE]
@export var display_name: String  # アイテムの表示名
@export_multiline var description: String  # アイテムの説明
@export var icon: Texture2D  # アイテムのアイコン
