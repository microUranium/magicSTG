# ExplosionEffect.gd - 爆発エフェクト処理
extends Node2D
class_name ExplosionEffect

var particles: GPUParticles2D
var damage_area: Area2D
var collision: CollisionShape2D
var audio_player: AudioStreamPlayer2D
var target_group: String = "enemies"  # デフォルトのターゲットグループ

var explosion_config: ExplosionConfig
var damage_dealt_targets: Array[Node] = []  # 重複ダメージ防止
var _cleanup_timer: Timer


func _ready():
  # ノード参照を取得
  particles = $GPUParticles2D
  damage_area = $DamageArea
  collision = $DamageArea/CollisionShape2D
  audio_player = $AudioStreamPlayer2D

  # 初期化が先に呼ばれていた場合は処理を実行
  if explosion_config:
    _setup_visual_effect()
    _setup_damage_area()
    _setup_audio()
    _start_explosion()


func initialize(config: ExplosionConfig, position: Vector2, target: String):
  explosion_config = config
  global_position = position
  target_group = target

  # _ready()が既に呼ばれている場合は即座に処理
  if particles:
    _setup_visual_effect()
    _setup_damage_area()
    _setup_audio()
    _start_explosion()


func _setup_visual_effect():
  if explosion_config.explosion_particle_material and particles:
    particles.process_material = explosion_config.explosion_particle_material
    particles.scale = Vector2.ONE * explosion_config.explosion_scale
    particles.one_shot = true


func _setup_damage_area():
  if explosion_config.explosion_damage <= 0 or explosion_config.explosion_radius <= 0:
    damage_area.queue_free()
    return

  # コリジョンレイヤー設定
  damage_area.collision_layer = 4
  damage_area.collision_mask = 3
  damage_area.monitoring = true

  # コリジョン形状設定
  var shape = CircleShape2D.new()
  shape.radius = explosion_config.explosion_radius
  collision.shape = shape

  # シグナル接続（Callable形式で安定化）
  damage_area.connect("area_entered", Callable(self, "_on_damage_area_entered"))


func _setup_audio():
  if explosion_config.explosion_sound and audio_player:
    audio_player.stream = explosion_config.explosion_sound
    audio_player.play()


func _start_explosion():
  if particles:
    particles.restart()

  # エフェクト完了後のクリーンアップタイマー
  _cleanup_timer = Timer.new()
  _cleanup_timer.wait_time = explosion_config.explosion_duration
  _cleanup_timer.one_shot = true
  _cleanup_timer.timeout.connect(_on_explosion_complete)
  add_child(_cleanup_timer)
  _cleanup_timer.start()


func _on_damage_area_entered(area):
  _deal_damage_to_target(area)


func _deal_damage_to_target(target: Node):
  if not target.is_in_group(target_group):
    return

  if target in damage_dealt_targets:
    return  # 重複ダメージ防止

  damage_dealt_targets.append(target)

  var damage = explosion_config.explosion_damage

  # 距離による減衰計算
  if explosion_config.damage_falloff:
    var distance = global_position.distance_to(target.global_position)
    var falloff_factor = 1.0 - (distance / explosion_config.explosion_radius)
    falloff_factor = max(0.1, falloff_factor)  # 最小10%のダメージ保証
    damage = int(damage * falloff_factor)

  # ダメージ適用
  if target.has_method("take_damage"):
    target.take_damage(damage)


func _on_explosion_complete():
  queue_free()


func reset():
  """オブジェクトプール用のリセット処理"""
  explosion_config = null
  damage_dealt_targets.clear()
  if _cleanup_timer:
    _cleanup_timer.queue_free()
    _cleanup_timer = null
