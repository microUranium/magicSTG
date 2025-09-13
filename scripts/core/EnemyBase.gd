extends Area2D
class_name EnemyBase

@export
var destroy_particles_scene: PackedScene = preload("res://scenes/enemy/destroy_particle.tscn")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slot := $AttackCoreSlot
@export var drop_table: Array[DropTableEntry] = []
@export var skip_boss_defeat_effect: bool = false  # ボス撃破エフェクトをスキップするかどうか

var _damage_flash_time: float


func _ready():
  add_to_group("enemies")
  $HpNode.connect("hp_changed", Callable(self, "on_hp_changed"))
  animated_sprite.play("default")


func take_damage(amount: int) -> void:
  $HpNode.take_damage(amount)
  StageSignals.emit_signal("sfx_play_requested", "hit_enemy", global_position, -10, 0)
  flash_white()


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if current_hp <= 0:
    _spawn_destroy_particles()
    _drop_item()
    StageSignals.emit_signal("sfx_play_requested", "destroy_enemy", global_position, 0, 0)
    queue_free()


func _spawn_destroy_particles():
  if destroy_particles_scene:
    var p: CPUParticles2D = destroy_particles_scene.instantiate()
    get_tree().current_scene.add_child(p)
    p.global_position = global_position
    p.restart()


func _drop_item() -> void:
  if drop_table.size() > 0:
    LootSystem.spawn_drop(global_position, drop_table)


func set_parameter(_name: String, _value: String) -> void:
  # 継承先で実装されることを期待
  pass


func _process(delta: float) -> void:
  _update_flashing(delta)


func _update_flashing(delta):
  if _damage_flash_time > 0.0:
    _damage_flash_time -= delta
    animated_sprite.modulate = Color(1.0, 0.35, 0.35, animated_sprite.modulate.a)

  if _damage_flash_time <= 0.0:
    animated_sprite.modulate = Color(1.0, 1.0, 1.0, animated_sprite.modulate.a)
    _damage_flash_time = 0.0


func flash_white(duration := 0.1):
  print_debug("EnemyBase: Flashing white for ", duration, " seconds")
  _damage_flash_time = duration
