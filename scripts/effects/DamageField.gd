# DamageField.gd - 一定時間、範囲内の対象に一定間隔でダメージを与え続ける円形の領域
# 爆発の設定（ExplosionConfig.damage_field）から ExplosionFactory が生成する。
# 範囲がわかるよう、半透明の円を描き、出ている間は円の中にパーティクル（既定の四角）を出し続ける。
extends Area2D

const MAX_TICKS_PER_FRAME := 4  # 処理落ちで1フレームが長くなっても、一度に与えるダメージ回数の上限

var config: Resource = null  # DamageFieldConfig
var target_group: String = "players"

var _elapsed: float = 0.0
var _tick_accum: float = 0.0
var _active: bool = true
var _particles: GPUParticles2D = null
var _area_fade: float = 1.0  # 範囲の円の濃さ（終了時に 1 → 0 へ薄くする）


func setup(field_config: Resource, position_: Vector2, group: String) -> void:
  """シーンに追加する前に呼ぶ"""
  config = field_config
  global_position = position_
  target_group = group


func _ready() -> void:
  # 爆発のダメージ判定（ExplosionEffect）と同じレイヤー設定
  collision_layer = 4
  collision_mask = 3
  monitoring = true
  monitorable = false

  var shape := CircleShape2D.new()
  shape.radius = config.radius
  var collision := CollisionShape2D.new()
  collision.shape = shape
  add_child(collision)

  _particles = _create_particles()
  add_child(_particles)

  # 弾の一斉消去（ボスのフェーズ切り替え・打消の加護など）ではフィールドも消す
  StageSignals.destroy_bullet.connect(_on_destroy_all)
  StageSignals.destroy_bullets_by_target.connect(_on_destroy_by_target)


func _draw() -> void:
  # 範囲を示す半透明の円。子のパーティクルはこの上に描かれる
  draw_circle(Vector2.ZERO, config.radius, get_area_color())


func get_area_color() -> Color:
  var color: Color = config.area_color
  color.a *= _area_fade
  return color


func _set_area_fade(value: float) -> void:
  _area_fade = value
  queue_redraw()


func _create_particles() -> GPUParticles2D:
  var process_mat := ParticleProcessMaterial.new()
  process_mat.particle_flag_disable_z = true
  process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE  # 2D では円の内側から出る
  process_mat.emission_sphere_radius = config.radius
  process_mat.direction = Vector3(0, -1, 0)
  process_mat.spread = 180.0
  process_mat.initial_velocity_min = 5.0
  process_mat.initial_velocity_max = 25.0
  process_mat.gravity = Vector3(0, -30, 0)  # ゆっくり立ち上る
  process_mat.scale_min = config.particle_scale_min
  process_mat.scale_max = config.particle_scale_max
  # 色：寿命に沿って particle_color → particle_end_color（初期値は白）へ徐々に変える
  var color_ramp := Gradient.new()
  color_ramp.set_color(0, config.particle_color)
  color_ramp.set_color(1, config.particle_end_color)
  var color_tex := GradientTexture1D.new()
  color_tex.gradient = color_ramp
  process_mat.color_ramp = color_tex
  # 透明度：色とは別に、寿命の終わりに向けて透明にする
  var fade := Curve.new()
  fade.add_point(Vector2(0.0, 1.0))
  fade.add_point(Vector2(1.0, 0.0))
  var fade_tex := CurveTexture.new()
  fade_tex.curve = fade
  process_mat.alpha_curve = fade_tex

  var particles := GPUParticles2D.new()
  particles.process_material = process_mat
  particles.amount = config.particle_amount
  particles.lifetime = config.particle_lifetime
  particles.emitting = true  # テクスチャは設定しない（既定の四角で描く）
  return particles


func _process(delta: float) -> void:
  if not _active:
    return
  _elapsed += delta
  _tick_accum += delta
  var ticks := 0
  while _tick_accum >= config.tick_sec and ticks < MAX_TICKS_PER_FRAME:
    _tick_accum -= config.tick_sec
    ticks += 1
    _deal_damage()
  if _elapsed >= config.duration:
    _finish()


func _deal_damage() -> void:
  for target in get_overlapping_areas() + get_overlapping_bodies():
    if target.is_in_group(target_group) and target.has_method("take_damage"):
      target.take_damage(config.damage)


func is_active() -> bool:
  return _active


func _finish() -> void:
  """持続時間が過ぎたら当たり判定と放出を止め、範囲の円を薄くしながら、
  残ったパーティクルが消えてから自分を消す"""
  _active = false
  set_deferred("monitoring", false)
  if _particles:
    _particles.emitting = false
  create_tween().tween_method(_set_area_fade, 1.0, 0.0, config.particle_lifetime)
  get_tree().create_timer(config.particle_lifetime, false).timeout.connect(queue_free)


func _on_destroy_all() -> void:
  queue_free()


func _on_destroy_by_target(group: String) -> void:
  if group == target_group:
    queue_free()
