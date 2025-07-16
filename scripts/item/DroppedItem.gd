extends Area2D
class_name DroppedItem

var item_instance: ItemInstance
var player: Player
var speed: float = 100.0  # プレイヤーに向かう速度

@export var item_image_blessing: Texture2D
@export var item_image_core: Texture2D
@onready var sprite := $Sprite2D


func _ready() -> void:
  connect("area_entered", Callable(self, "_on_area_entered"))
  if item_instance.prototype.item_type == item_instance.prototype.ItemType.BLESSING:
    sprite.texture = item_image_blessing
  else:
    sprite.texture = item_image_core

  # ランダムな方向に向かって少し移動
  var angle: float = randf() * 2 * PI
  speed = 50
  var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed
  var tw := create_tween()
  tw.tween_property(self, "position", position + velocity, 0.5)
  tw.set_ease(Tween.EASE_IN_OUT)
  tw.play()

  # 0.5秒後にプレイヤーに向かって移動
  await get_tree().create_timer(0.5).timeout
  player = get_tree().current_scene.get_node_or_null("Player")
  speed = 300  # プレイヤーに向かう速度を設定
  # 徐々に加速
  var acceleration: float = 1000.0  # 加速量
  var tw_accel := create_tween()
  tw_accel.tween_property(self, "speed", speed + acceleration, 1.5)
  tw_accel.set_ease(Tween.EASE_IN_OUT)
  tw_accel.play()


func _process(delta: float) -> void:
  if player:
    var direction: Vector2 = (player.global_position - global_position).normalized()
    position += direction * speed * delta  # プレイヤーに向かって移動


func _on_area_entered(body: Node) -> void:
  if body is Player:
    if InventoryService.try_add(item_instance):
      StageSignals.emit_signal("sfx_play_requested", "get_item", global_position, 0, 0)
      queue_free()
