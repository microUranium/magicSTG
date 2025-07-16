extends Area2D
class_name DroppedItem

var item_instance: ItemInstance
@onready var sprite := $Sprite2D


func _ready() -> void:
  connect("area_entered", Callable(self, "_on_area_entered"))


func _on_area_entered(body: Node) -> void:
  if body is Player:
    if InventoryService.try_add(item_instance):
      queue_free()
