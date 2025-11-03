extends Sprite2D
class_name AfterImage

@export var lifetime: float = 0.5  # エフェクトの寿命（秒）


func _ready():
  var tween = create_tween()
  tween.tween_property(self, "modulate:a", 0.0, lifetime)
  await tween.finished
  queue_free()
