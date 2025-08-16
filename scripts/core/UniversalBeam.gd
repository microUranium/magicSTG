# 汎用ビームクラス - プレイヤー・敵共通で使用可能
extends Area2D
class_name UniversalBeam

# === 基本設定 ===
@export var damage: int = 1
@export var desired_length: float = 1000.0
@export var target_group: String = "enemies"
@export var damage_tick_sec: float = 1.0 / 30.0
@export var offset: Vector2 = Vector2.ZERO  # ビームのオフセット位置

# === 視覚・方向設定 ===
@export var beam_visual_config: BeamVisualConfig
@export var beam_direction: Vector2 = Vector2.UP
@export var owner_path: NodePath

# === 内部状態 ===
var owner_node: Node2D
var _current_length: float = 0.0
var _colliding_targets: Array[Node] = []  # 現在コリジョン中のターゲット

# === コンポーネント ===
@onready var ninepatch: NinePatchRect = $NinePatchRect
@onready var shape: RectangleShape2D = $CollisionShape2D.shape
@onready var raycast: RayCast2D = $RayCast2D
@onready var dmg_timer: Timer = $DamageTimer
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var muzzle_flash_point: Node2D = $MuzzleFlashPoint
@onready var impact_effect_point: Node2D = $ImpactEffectPoint


func _ready():
  _setup_raycast()
  _setup_damage_timer()
  _apply_visual_config()
  _initialize_owner()
  _setup_collision_signals()


func initialize(_owner_node: Node2D, _damage: int, direction: Vector2 = Vector2.UP) -> void:
  """ビームの初期化"""
  self.owner_node = _owner_node
  self.damage = _damage
  self.beam_direction = direction.normalized()
  _setup_raycast()


func set_target_group(group: String) -> void:
  """ターゲットグループの設定"""
  target_group = group


func set_beam_direction(direction: Vector2) -> void:
  """ビーム方向の設定"""
  beam_direction = direction.normalized()
  if raycast:
    raycast.target_position = beam_direction * desired_length
  # ビーム全体の回転
  rotation = beam_direction.angle() + PI / 2


func apply_visual_config(config: BeamVisualConfig = null) -> void:
  """視覚設定の適用"""
  if config:
    beam_visual_config = config
  _apply_visual_config()


func _setup_raycast():
  """RayCast設定"""
  if not raycast:
    return
  raycast.target_position = beam_direction * desired_length
  raycast.enabled = true
  raycast.exclude_parent = true


func _setup_damage_timer():
  """ダメージタイマー設定"""
  if not dmg_timer:
    return
  dmg_timer.wait_time = damage_tick_sec
  dmg_timer.timeout.connect(_on_damage_tick)
  dmg_timer.start()


func _setup_collision_signals():
  """コリジョン信号の設定"""
  area_entered.connect(_on_area_entered)
  area_exited.connect(_on_area_exited)


func _initialize_owner():
  """オーナー設定"""
  if owner_path != NodePath():
    owner_node = get_node(owner_path)


func _apply_visual_config():
  """視覚設定の適用"""
  if not beam_visual_config:
    return

  var config = beam_visual_config

  # NinePatchRect設定
  if ninepatch:
    if config.texture:
      ninepatch.texture = config.texture
    ninepatch.modulate = config.color
    scale = config.scale

    # 幅設定
    ninepatch.size.x = config.width

  # マテリアル設定
  if config.material and ninepatch:
    ninepatch.material = config.material

  # パーティクル設定
  if particles:
    particles.visible = config.enable_particles
    if config.enable_particles and config.particle_material:
      particles.process_material = config.particle_material

  # 音声設定
  if config.fire_sound and audio_player:
    audio_player.stream = config.fire_sound
    audio_player.volume_db = linear_to_db(config.volume)
    audio_player.play()


func _process(_delta: float) -> void:
  _update_position()
  _update_length()


func _update_position():
  """位置更新"""
  # owner_nodeの有効性チェック
  if not is_instance_valid(owner_node):
    cleanup()
    return

  if owner_node:
    global_position = owner_node.global_position + offset


func _update_length():
  """長さ更新"""
  var length := desired_length

  # RayCastは視覚的な長さ調整のみに使用（障害物との衝突検出）
  if raycast and raycast.is_colliding():
    var col := raycast.get_collider()
    # 障害物（地形など）との衝突で長さを制限
    if col and col.is_in_group(target_group):
      length = global_position.distance_to(raycast.get_collision_point())

  if length != _current_length:
    _apply_length(length)
    _current_length = length


func _apply_length(length: float) -> void:
  """長さ適用"""
  if ninepatch:
    # 方向に応じた長さ適用
    ninepatch.size.y = length
    ninepatch.position = Vector2(-ninepatch.size.x * 0.5, -length)

  # コリジョン設定
  if shape:
    shape.extents.y = length * 0.5
    var collision_node = $CollisionShape2D
    if collision_node:
      collision_node.position = Vector2(0, -length * 0.5)

  # エフェクト位置更新
  if impact_effect_point:
    impact_effect_point.position = beam_direction * (-length)


func _on_damage_tick() -> void:
  """ダメージ処理（コリジョン判定）"""
  _play_beam_sound()

  # コリジョン中のすべてのターゲットにダメージ
  for target in _colliding_targets:
    if is_instance_valid(target) and target.is_in_group(target_group):
      if target.has_method("take_damage"):
        target.take_damage(damage)
        _spawn_impact_effect_at_target(target)

  # 無効なターゲットを削除
  _colliding_targets = _colliding_targets.filter(func(target): return is_instance_valid(target))


func _play_beam_sound():
  """ビーム音再生"""
  var sound_name = "shot_beam"  # デフォルト音
  if beam_visual_config and beam_visual_config.loop_sound:
    # カスタム音がある場合は直接再生
    if audio_player and audio_player.stream != beam_visual_config.loop_sound:
      audio_player.stream = beam_visual_config.loop_sound
      audio_player.play()
  else:
    # SFXシステム経由
    StageSignals.sfx_play_requested.emit(sound_name, global_position, 0, 1.0)


func _spawn_impact_effect_at_target(target: Node):
  """特定ターゲットでの衝撃エフェクト生成"""
  if not beam_visual_config or not beam_visual_config.impact_effect:
    return

  var effect = beam_visual_config.impact_effect.instantiate()
  get_tree().current_scene.add_child(effect)
  effect.global_position = target.global_position


func _spawn_impact_effect():
  """汎用衝撃エフェクト生成（従来互換）"""
  if not beam_visual_config or not beam_visual_config.impact_effect:
    return

  var effect = beam_visual_config.impact_effect.instantiate()
  get_tree().current_scene.add_child(effect)
  effect.global_position = impact_effect_point.global_position


func _on_area_entered(area: Area2D) -> void:
  """Area2Dとの衝突開始"""
  if area.is_in_group(target_group) and area not in _colliding_targets:
    _colliding_targets.append(area)


func _on_area_exited(area: Area2D) -> void:
  """Area2Dとの衝突終了"""
  if area in _colliding_targets:
    _colliding_targets.erase(area)


func cleanup():
  """クリーンアップ処理"""
  if beam_visual_config and beam_visual_config.end_sound and audio_player:
    audio_player.stream = beam_visual_config.end_sound
    audio_player.play()

  _colliding_targets.clear()

  queue_free()
