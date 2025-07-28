# 設定駆動型のバリア弾 - 旧HarpyBulletBarrierを汎用化
extends "res://scripts/player/ProjectileBullet.gd"
class_name EnhancedBarrierBullet

# === 設定可能なプロパティ ===
@export var bullet_config: BulletVisualConfig
@export var movement_config: BarrierBulletMovement

# === 内部コンポーネント ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

# === 内部状態 ===
var owner_node: Node2D
var target_node: Node2D
var bullet_group: String
var bullet_index: int
var bullet_total: int

var _current_phase: BarrierBulletMovement.Phase = BarrierBulletMovement.Phase.MOVING_TO_ORBIT
var _orbit_angle: float = 0.0
var _phase_timer: float = 0.0
var _orbit_center: Vector2
var _current_orbit_radius: float = 0.0


func _ready():
  super._ready()
  apply_visual_config()
  apply_barrier_movement_config()


func setup_barrier_bullet(
  owner: Node2D,
  group_id: String,
  total: int,
  index: int,
  target: Node2D = null,
  radius: float = 100.0,
  dmg: int = 5,
  target_grp: String = "enemies",
):
  """バリア弾の初期設定"""
  owner_node = owner
  bullet_group = group_id
  bullet_total = total
  bullet_index = index
  target_node = target
  damage = dmg
  target_group = target_grp

  # 設定を動的に更新
  movement_config.orbit_radius = radius

  if not bullet_group.is_empty():
    add_to_group(bullet_group)
  _orbit_center = owner_node.global_position if owner_node else global_position
  _calculate_initial_orbit_position()


func start_rotation(duration: float = 3.0, rotation_speed: float = 90.0):
  """回転開始"""
  movement_config.orbit_duration = duration
  movement_config.rotation_speed = rotation_speed

  # 軌道への移動を開始
  var tween = create_tween()
  tween.tween_property(
    self, "_current_orbit_radius", movement_config.orbit_radius, movement_config.approach_duration
  )

  # フェーズタイマー開始
  _phase_timer = 0.0


func apply_visual_config(_bullet_config: BulletVisualConfig = null):
  """視覚設定の適用"""
  if not _bullet_config:
    bullet_config = BulletVisualConfig.new()
  else:
    bullet_config = _bullet_config

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


func apply_barrier_movement_config(_movement_config: BarrierBulletMovement = null):
  """移動設定の適用"""
  if not _movement_config:
    movement_config = BarrierBulletMovement.new()
  else:
    movement_config = _movement_config

  speed = movement_config.projectile_speed
  print_debug(
    "EnhancedBarrierBullet: apply_movement_config",
    "Speed:",
    speed,
    "Orbit Radius:",
    movement_config.orbit_radius,
    "Approach Duration:",
    movement_config.approach_duration,
    "Orbit Duration:",
    movement_config.orbit_duration
  )


func _process(delta):
  # 画面外チェック
  if not PlayArea.get_play_rect().has_point(global_position):
    queue_free()
    return

    # オーナーが無効になったら削除
  if owner_node == null or not owner_node.is_inside_tree():
    queue_free()
    return
  _phase_timer += delta
  _update_movement(delta)


func _update_movement(delta: float):
  """フェーズに応じた移動処理"""
  match _current_phase:
    BarrierBulletMovement.Phase.MOVING_TO_ORBIT:
      _update_approach_phase(delta)
    BarrierBulletMovement.Phase.ORBITING:
      _update_orbit_phase(delta)
    BarrierBulletMovement.Phase.PROJECTILE:
      _update_projectile_phase(delta)


func _update_approach_phase(delta: float):
  """軌道への接近フェーズ"""
  if _phase_timer >= movement_config.approach_duration:
    _current_phase = BarrierBulletMovement.Phase.ORBITING
    _phase_timer = 0.0
    return

  # 軌道中心を更新
  if owner_node:
    _orbit_center = owner_node.global_position

  # 現在の軌道位置を計算
  _calculate_orbit_position()


func _update_orbit_phase(delta: float):
  """軌道回転フェーズ"""
  if _phase_timer >= movement_config.orbit_duration:
    _transition_to_projectile()
    return

  # 回転角度を更新
  _orbit_angle += movement_config.rotation_speed * delta
  _orbit_angle = wrapf(_orbit_angle, 0.0, 360.0)

  # 軌道中心を更新
  if owner_node:
    _orbit_center = owner_node.global_position

  # 軌道位置を計算
  _calculate_orbit_position()


func _update_projectile_phase(delta: float):
  """直進フェーズ"""
  position += direction * speed * delta


func _transition_to_projectile():
  """直進フェーズへの移行"""
  _current_phase = BarrierBulletMovement.Phase.PROJECTILE

  # 直進方向を決定
  match movement_config.projectile_direction_type:
    BarrierBulletMovement.ProjectileDirection.TO_TARGET:
      if target_node:
        direction = (target_node.global_position - global_position).normalized()
      else:
        direction = Vector2.DOWN  # フォールバック
    # 現在の軌道方向を維持
    BarrierBulletMovement.ProjectileDirection.CURRENT_VELOCITY:
      # 現在の軌道方向を維持
      var tangent_angle = deg_to_rad(_orbit_angle + 90.0)  # 軌道の接線方向
      direction = Vector2.RIGHT.rotated(tangent_angle)
    BarrierBulletMovement.ProjectileDirection.FIXED:
      direction = movement_config.fixed_direction.normalized()
    BarrierBulletMovement.ProjectileDirection.RANDOM:
      direction = Vector2.from_angle(randf() * TAU)


func _calculate_initial_orbit_position():
  """初期軌道位置を計算"""
  var angle_step = 360.0 / max(bullet_total, 1)
  _orbit_angle = angle_step * bullet_index
  _calculate_orbit_position()


func _calculate_orbit_position():
  """現在の軌道位置を計算して適用"""
  var angle_rad = deg_to_rad(_orbit_angle)
  var offset = Vector2(0, -_current_orbit_radius).rotated(angle_rad)
  global_position = _orbit_center + offset
