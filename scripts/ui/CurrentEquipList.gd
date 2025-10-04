extends Control
class_name CurrentEquipList

var item_instance: ItemInstance


func setup_item(i: ItemInstance) -> void:
  item_instance = i


func _ready() -> void:
  if item_instance:
    var icon: TextureRect = $Icon
    var frame: TextureRect = $Frame
    var label: Label = $Label

    # アイコンとアイテム名の設定
    if item_instance.prototype:
      if item_instance.prototype.icon:
        icon.texture = item_instance.prototype.icon
      frame.modulate = item_instance.get_rarity_color()
      label.text = item_instance.prototype.display_name
