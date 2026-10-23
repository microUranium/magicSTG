extends Node2D
## 高レアリティのドロップアイテムに付ける演出
##
## 子ノードは名前の接頭辞で役割を決める:
##   Spawn*  : 出現時に一度だけ再生する CPUParticles2D
##   Loop*   : 浮遊中ずっと再生する CPUParticles2D
##   Pickup* : 取得時に一度だけ再生する CPUParticles2D（アイテム消滅後も残るようシーン直下へ移す）
##   Glow    : アイテムの背後で明滅する Sprite2D

@export var glow_scale_min: float = 1.4
@export var glow_scale_max: float = 1.8
@export var glow_pulse_sec: float = 0.8

@onready var _glow: Sprite2D = get_node_or_null("Glow")


func _ready() -> void:
  for child in _particles_with_prefix("Spawn"):
    child.restart()
  for child in _particles_with_prefix("Loop"):
    child.emitting = true
  for child in _particles_with_prefix("Pickup"):
    child.emitting = false
  _start_glow_pulse()


## 取得時の演出を再生する。呼び出し元（アイテム）がすぐ消えても演出は最後まで残る
func play_pickup() -> void:
  var scene_root := get_tree().current_scene if get_tree().current_scene else get_tree().root
  for child in _particles_with_prefix("Loop"):
    _detach(child, scene_root)
    child.emitting = false  # 出ている粒子はそのまま消えていく
  for child in _particles_with_prefix("Pickup"):
    _detach(child, scene_root)
    child.restart()


func _particles_with_prefix(prefix: String) -> Array[CPUParticles2D]:
  var result: Array[CPUParticles2D] = []
  for child in get_children():
    if child is CPUParticles2D and child.name.begins_with(prefix):
      result.append(child)
  return result


func _detach(particles: CPUParticles2D, new_parent: Node) -> void:
  particles.reparent(new_parent)
  get_tree().create_timer(particles.lifetime + 0.1, false).timeout.connect(particles.queue_free)


func _start_glow_pulse() -> void:
  if _glow == null:
    return
  _glow.scale = Vector2.ONE * glow_scale_min
  var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  tw.tween_property(_glow, "scale", Vector2.ONE * glow_scale_max, glow_pulse_sec * 0.5)
  tw.tween_property(_glow, "scale", Vector2.ONE * glow_scale_min, glow_pulse_sec * 0.5)
