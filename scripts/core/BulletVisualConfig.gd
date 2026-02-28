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

@export_group("Fade Effects")
## フェードイン開始時の初期アルファ値（0.0~1.0）
## 0.0から開始すると視認性が低いため、0.3～0.5程度を推奨
@export_range(0.0, 1.0) var fade_in_initial_alpha: float = 1.0
## フェードイン完了までの時間（秒）
## 0の場合はフェードインなし（即座にfull alpha）
@export var fade_in_duration: float = 0.0
## フェードアウト完了までの時間（秒）
## 0の場合はフェードアウトなし（即座に削除）
@export var fade_out_duration: float = 0.0
