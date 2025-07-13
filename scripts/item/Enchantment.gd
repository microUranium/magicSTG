extends Resource
class_name Enchantment

@export var id: StringName  # 一意識別子
@export var display_name: String  # 表示名
@export_multiline var description: String  # 説明
@export var modifiers: Dictionary = {}
