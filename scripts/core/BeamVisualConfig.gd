# ビームの視覚設定リソース
class_name BeamVisualConfig extends Resource

# === 基本視覚設定 ===
@export var texture: Texture2D
@export var color: Color = Color.WHITE
@export var width: float = 32.0  # ビーム幅
@export var scale: Vector2 = Vector2.ONE

# === マテリアル設定 ===
@export var material: ShaderMaterial
@export var use_shader_animation: bool = true
@export var animation_speed: float = 12.0  # FPS

# === エフェクト設定 ===
@export var enable_particles: bool = false
@export var particle_material: ParticleProcessMaterial
@export var muzzle_flash: PackedScene
@export var impact_effect: PackedScene

# === 音声設定 ===
@export var fire_sound: AudioStream
@export var loop_sound: AudioStream
@export var end_sound: AudioStream
@export var volume: float = 1.0
