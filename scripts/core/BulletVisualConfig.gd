# 弾丸の視覚設定
class_name BulletVisualConfig extends Resource

@export var texture: Texture2D
@export var scale: float = 1.0
@export var color: Color = Color.WHITE
@export var collision_radius: float = 8.0

@export var enable_particles: bool = false
@export var particle_material: ParticleProcessMaterial

@export var animation_name: String = ""
@export var spawn_sound: AudioStream
