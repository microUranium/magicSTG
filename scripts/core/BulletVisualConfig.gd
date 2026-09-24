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

@export_group("Afterimage")
## 残像（弾のスプライトを複製してフェードさせる）を出すか。
## 既定 false なので既存の弾は無変更で従来どおり動く。
@export var enable_afterimage: bool = false
## 残像を生成する間隔（秒）。時間ベースなのでフレームレートに依存しない
@export var afterimage_interval: float = 0.05
## 残像1枚が消えるまでの時間（秒）
@export var afterimage_lifetime: float = 0.25
## 残像の色（アルファで濃さを決める）
@export var afterimage_color: Color = Color(1, 1, 1, 0.45)

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
