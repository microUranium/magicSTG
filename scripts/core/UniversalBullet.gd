# UniversalBullet.gd - 汎用弾丸スクリプト
extends "res://scripts/player/ProjectileBullet.gd"
class_name UniversalBullet

# === 視覚設定 ===
@export var bullet_config: BulletVisualConfig
@export var movement_config: BulletMovementConfig

# === 内部コンポーネント ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

# === 内部状態 ===
var _movement_timer: float = 0.0
var _original_speed: float


func _ready():
  super._ready()
  _original_speed = speed
  apply_visual_config()
  apply_movement_config()


func apply_visual_config(_bullet_config: BulletVisualConfig = null):
  """視覚設定の適用"""
  if _bullet_config:
    bullet_config = _bullet_config

  if not bullet_config:
    return

  # スプライト設定
  if bullet_config.texture:
    sprite.texture = bullet_config.texture

  sprite.scale = Vector2(bullet_config.scale, bullet_config.scale)
  sprite.modulate = bullet_config.color

  # コリジョン設定
  if bullet_config.collision_radius > 0:
    var shape = CircleShape2D.new()
    shape.radius = bullet_config.collision_radius
    collision.shape = shape

  # パーティクル設定
  if bullet_config.enable_particles and particles:
    particles.visible = true
    if bullet_config.particle_material:
      particles.process_material = bullet_config.particle_material
  else:
    if particles:
      particles.visible = false

  # アニメーション設定
  if bullet_config.animation_name and animation_player:
    animation_player.play(bullet_config.animation_name)

  # 音声設定
  if bullet_config.spawn_sound and audio_player:
    audio_player.stream = bullet_config.spawn_sound
    audio_player.play()


func apply_movement_config(_movement_config: BulletMovementConfig = null):
  """移動設定の適用"""
  if _movement_config:
    movement_config = _movement_config

  if not movement_config:
    return
  speed = movement_config.initial_speed
  _original_speed = speed


func _process(delta):
  super._process(delta)

  if movement_config:
    _update_advanced_movement(delta)


func _update_advanced_movement(delta: float):
  """高度な移動処理"""
  _movement_timer += delta

  match movement_config.movement_type:
    BulletMovementConfig.MovementType.STRAIGHT:
      # デフォルトの直進（何もしない）
      pass
    BulletMovementConfig.MovementType.DECELERATE:
      _update_deceleration(delta)
    BulletMovementConfig.MovementType.ACCELERATE:
      _update_acceleration(delta)
    BulletMovementConfig.MovementType.SINE_WAVE:
      _update_sine_wave(delta)
    BulletMovementConfig.MovementType.HOMING:
      _update_homing(delta)


func _update_deceleration(delta: float):
  """減速処理"""
  var decel_rate = movement_config.deceleration_rate
  speed = max(movement_config.min_speed, speed - decel_rate * delta)


func _update_acceleration(delta: float):
  """加速処理"""
  var accel_rate = movement_config.acceleration_rate
  speed = min(movement_config.max_speed, speed + accel_rate * delta)


func _update_sine_wave(delta: float):
  """サイン波軌道"""
  var wave_amplitude = movement_config.wave_amplitude
  var wave_frequency = movement_config.wave_frequency

  var perpendicular = Vector2(-direction.y, direction.x)
  var wave_offset = sin(_movement_timer * wave_frequency) * wave_amplitude

  # 基本的な前進 + サイン波の横移動
  position += direction * speed * delta
  position += perpendicular * wave_offset * delta


func _update_homing(delta: float):
  """追尾処理"""
  var target = _find_homing_target()
  if target:
    var target_direction = (target.global_position - global_position).normalized()
    var turn_rate = movement_config.homing_turn_rate
    direction = direction.slerp(target_direction, turn_rate * delta)


func _find_homing_target() -> Node2D:
  """追尾対象を検索"""
  var targets = get_tree().get_nodes_in_group(target_group)
  if targets.is_empty():
    return null

  # 最も近い対象を選択
  var closest_target = null
  var closest_distance = INF

  for target in targets:
    if target is Node2D:
      var distance = global_position.distance_to(target.global_position)
      if distance < closest_distance:
        closest_distance = distance
        closest_target = target
  return closest_target
