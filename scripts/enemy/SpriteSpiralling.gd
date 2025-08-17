extends Node2D
class_name SpriteSpiralling

@export var spiral_speed: float = 1.0  # スパイラルの回転速度


func _process(delta: float) -> void:
  """スプライトをスパイラル状に回転させる"""
  if not spiral_speed:
    return

  # スプライトの回転を更新
  rotation += spiral_speed * delta
