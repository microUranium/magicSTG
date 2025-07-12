extends Area2D

@export var target_group: String = "enemies"
@export var damage: int = 1

func _ready():
  connect("area_entered", Callable(self, "_on_area_entered"))
  StageSignals.destroy_bullet.connect(_destroy_bullet)

func _destroy_bullet() -> void:
  queue_free()

func _on_area_entered(body):
  if body.is_in_group(target_group):
    body.take_damage(damage) # 敵側に take_damage 実装がある前提
    queue_free()
