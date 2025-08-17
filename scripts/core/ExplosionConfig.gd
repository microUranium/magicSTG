# ExplosionConfig.gd - 爆発エフェクト設定
class_name ExplosionConfig extends Resource

@export_group("Visual Effects")
@export var explosion_particle_material: ParticleProcessMaterial
@export var explosion_sound: AudioStream
@export var explosion_scale: float = 1.0
@export var explosion_duration: float = 0.5

@export_group("Damage Properties")
@export var explosion_damage: int = 0  # 0 = ダメージなし
@export var explosion_radius: float = 0.0
@export var damage_falloff: bool = true  # 距離による減衰

@export_group("Advanced")
@export var explosion_type: ExplosionType = ExplosionType.NORMAL
@export var knockback_force: float = 0.0
@export var screen_shake_intensity: float = 0.0

enum ExplosionType { NORMAL, FIRE, ICE, LIGHTNING, POISON }
