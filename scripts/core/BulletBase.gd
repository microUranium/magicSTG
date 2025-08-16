extends Area2D
class_name BulletBase

@export var target_group: String = "enemies"
@export var damage: int = 1


func _ready():
  connect("area_entered", Callable(self, "_on_area_entered"))
  StageSignals.destroy_bullet.connect(_destroy_bullet)


func _destroy_bullet() -> void:
  _create_explosion_effect()
  _handle_particle_cleanup()
  queue_free()


func _handle_particle_cleanup():
  """パーティクルの適切なクリーンアップ処理"""
  # UniversalBulletでオーバーライド予定
  pass


func _create_explosion_effect():
  """爆発エフェクトの生成"""
  # UniversalBulletでオーバーライド予定
  pass


func _on_area_entered(body):
  if body.is_in_group(target_group):
    body.take_damage(damage)  # 敵側に take_damage 実装がある前提
    _create_explosion_effect()
    _handle_particle_cleanup()
    queue_free()
