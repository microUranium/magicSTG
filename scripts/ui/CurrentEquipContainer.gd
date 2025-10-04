extends Control
class_name CurrentEquipContainer

var _items: Array = []

var _equip_list_instance: PackedScene = preload("res://scenes/ui/current_equip_list.tscn")


func _ready() -> void:
  _refresh_items()


func _refresh_items() -> void:
  for child in get_children():
    child.queue_free()

  _items = PlayerSaveData.get_all_equipped_items()
  for item in _items:
    if not item is ItemInstance:
      continue
    print_debug("CurrentEquipContainer: adding item ", item.prototype.display_name)
    var instance = _equip_list_instance.instantiate() as CurrentEquipList
    instance.setup_item(item)
    add_child(instance)
