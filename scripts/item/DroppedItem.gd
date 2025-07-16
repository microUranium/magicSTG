extends Area2D
class_name DroppedItem

var item_instance: ItemInstance
@onready var sprite := $Sprite2D


func _ready() -> void:
  # プチ演出でランダムにバウンド
  # Area2D には apply_central_impulse() がないので、位置を直接アニメーション
  var random_offset = Vector2(randf_range(-50, 50), -100) * 0.02
  position += random_offset
  # アイコン差し替え
  sprite.texture = item_instance.prototype.icon  # 既存プロパティがあれば


func _on_body_entered(body: Node) -> void:
  if body is Player:
    body.pick_up(item_instance)
    queue_free()
