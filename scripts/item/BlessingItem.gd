extends ItemBase
class_name BlessingItem

@export var blessing_scene: PackedScene
@export var base_modifiers: Dictionary = {}  # 加護の基本的なパラメータ


func _init() -> void:
  item_type = ItemType.BLESSING
