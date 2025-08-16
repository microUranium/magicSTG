# 弾丸の視覚設定
class_name BulletVisualConfig extends Resource

@export_group("Basic Visual")
@export var texture: Texture2D
@export var scale: float = 1.0
@export var color: Color = Color.WHITE
@export var collision_radius: float = 8.0

@export_group("Trail Particles")
@export var enable_particles: bool = false
@export var particle_material: ParticleProcessMaterial

@export_group("Animation & Audio")
@export var animation_name: String = ""
@export var spawn_sound: AudioStream

@export_group("Explosion Effects")
@export var explosion_config: ExplosionConfig
