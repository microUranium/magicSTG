# 汎用ビームクラス - プレイヤー・敵共通で使用可能
extends Area2D
class_name UniversalBeam

## 当たり方:
##   ビームの中心に沿って幅 4px の帯（ShapeCast2D）を手前から調べ、target_group の相手を
##   手前から順に「貫通数 + 1」体まで集める。相手以外（弾・発射元の敵など）は読み飛ばす。
##   集め終えたら最後の相手のところでビームが止まり、足りなければ最大長まで伸びる。
##   集めた相手全員に damage_tick_sec ごとにダメージを与える（自弾なら加護の与ダメージ補正つき）。

const MAX_CAST_SKIPS := 32  # 相手を探すときに読み飛ばす相手以外（弾など）の上限

# === 基本設定 ===
@export var damage: int = 1
@export var desired_length: float = 1000.0
@export var target_group: String = "enemies"
@export var damage_tick_sec: float = 1.0 / 30.0
@export var offset: Vector2 = Vector2.ZERO  # ビームのオフセット位置
## 貫通数。0 = 最初の相手1体のみ、N = 手前から N+1 体、-1 = 無制限
@export var penetration_count: int = 0

# === 視覚・方向設定 ===
@export var beam_visual_config: BeamVisualConfig
@export var beam_direction: Vector2 = Vector2.UP
@export var owner_path: NodePath

# === 内部状態 ===
var owner_node: Node2D
var _current_length: float = 0.0
var _hits: Array[Node] = []  # ビームが現在捉えている相手（手前から順）
var _hit_end_length: float = 0.0  # 相手を集め終えた位置までの長さ（集めきれなければ最大長）
var _anim_time: float = 0.0  # シェーダーのコマ送り用の経過時間（ポーズ中は進まない）
var _anim_material: ShaderMaterial = null  # このビーム専用に複製したマテリアル

# === コンポーネント ===
@onready var ninepatch: NinePatchRect = $NinePatchRect
@onready var shape: RectangleShape2D = $CollisionShape2D.shape
@onready var shapecast: ShapeCast2D = $ShapeCast2D
@onready var dmg_timer: Timer = $DamageTimer
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var muzzle_flash_point: Node2D = $MuzzleFlashPoint
@onready var impact_effect_point: Node2D = $ImpactEffectPoint


func _ready():
  _setup_shapecast()
  _setup_damage_timer()
  _apply_visual_config()
  _setup_anim_material()
  _initialize_owner()
  _apply_direction()


func initialize(
  _owner_node: Node2D, _damage: int, direction: Vector2 = Vector2.UP, offset: Vector2 = Vector2.ZERO
) -> void:
  """ビームの初期化"""
  self.owner_node = _owner_node
  self.damage = _damage
  self.beam_direction = direction.normalized()
  self.offset = offset
  _apply_direction()


func set_target_group(group: String) -> void:
  """ターゲットグループの設定"""
  target_group = group


func set_beam_direction(direction: Vector2) -> void:
  """ビーム方向の設定"""
  beam_direction = direction.normalized()
  _apply_direction()


func apply_visual_config(config: BeamVisualConfig = null) -> void:
  """視覚設定の適用"""
  if config:
    beam_visual_config = config
  _apply_visual_config()
  _setup_anim_material()


func _apply_direction() -> void:
  """ビーム全体を beam_direction へ回転させる。
  子ノード（帯の判定・見た目）はビームから見て常に「上」（-Y）へ伸ばし、向きは回転だけで表す。
  （判定の向きにも方向ベクトルを掛けると回転が二重にかかり、真上以外で判定がずれる）"""
  if beam_direction != Vector2.ZERO:
    rotation = beam_direction.angle() + PI / 2
  if shapecast:
    shapecast.target_position = Vector2(0, -desired_length)


func _setup_shapecast():
  """帯の判定の設定。毎フレーム _update_hits() から手動で更新する"""
  if not shapecast:
    return
  shapecast.target_position = Vector2(0, -desired_length)
  shapecast.enabled = false
  shapecast.exclude_parent = true


func _setup_damage_timer():
  """ダメージタイマー設定"""
  if not dmg_timer:
    return
  dmg_timer.wait_time = damage_tick_sec
  dmg_timer.timeout.connect(_on_damage_tick)
  dmg_timer.start()


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


func _setup_anim_material() -> void:
  """シェーダーのコマ送りをビーム側の経過時間で進めるため、マテリアルをこのビーム専用に複製する。
  シーンや見た目設定のマテリアルは共有されているので、複製しないと他のビームと時間を取り合う。"""
  if not ninepatch or not (ninepatch.material is ShaderMaterial):
    return
  if ninepatch.material == _anim_material:
    return
  _anim_material = ninepatch.material.duplicate() as ShaderMaterial
  ninepatch.material = _anim_material
  _anim_material.set_shader_parameter("anim_time", _anim_time)


func _process(delta: float) -> void:
  _advance_animation(delta)
  _update_position()
  if is_queued_for_deletion():
    return
  _update_hits()
  _update_length()


func _advance_animation(delta: float) -> void:
  """コマ送りの時間を進める。ポーズ中は _process が止まるのでアニメーションも止まる
  （シェーダーの TIME はポーズ中も進むため使わない）"""
  _anim_time += delta
  if _anim_material:
    _anim_material.set_shader_parameter("anim_time", _anim_time)


func _update_position():
  """位置更新"""
  # owner_nodeの有効性チェック
  if not is_instance_valid(owner_node):
    cleanup()
    return

  if owner_node:
    global_position = owner_node.global_position + offset


func _required_hits() -> int:
  return penetration_count + 1 if penetration_count >= 0 else 1 << 30


## 帯の判定で、手前から target_group の相手を「貫通数 + 1」体まで集める。
## ShapeCast2D は最初に当たった位置で重なっているものしか返さないため、
## 当たったものを除外しては調べ直すことを繰り返す。
## 帯（幅 4px）の進行方向の厚みはシーン側で 8px にしている。当たった物の一覧は
## 「当たり位置を少し過ぎた位置（最大 ≒ 4px 先）」で集め直されるため、厚みが薄いと
## 小さな相手を通り過ぎて何も重なっていない判定になる。
func _update_hits() -> void:
  _hits.clear()
  _hit_end_length = desired_length
  if not shapecast:
    return

  var required := _required_hits()
  shapecast.clear_exceptions()
  var skips := 0
  while skips <= MAX_CAST_SKIPS:
    shapecast.force_shapecast_update()
    if not shapecast.is_colliding():
      break

    var excluded_any := false
    for i in shapecast.get_collision_count():
      var col = shapecast.get_collider(i)
      if col == null:
        continue
      if col is Node and col.is_in_group(target_group) and col not in _hits:
        _hits.append(col)
        if _hits.size() >= required:
          _hit_end_length = _axis_length_to(shapecast.get_collision_point(i))
          shapecast.clear_exceptions()
          return
      else:
        skips += 1
      if col is CollisionObject2D:
        shapecast.add_exception(col)
        excluded_any = true

    if not excluded_any:
      break  # 除外できない相手しかいない場合は無限ループを避けて打ち切る
  shapecast.clear_exceptions()


func _axis_length_to(point: Vector2) -> float:
  """ビームの根元から、当たった点までのビーム方向の長さ。
  ShapeCast2D の当たり位置の割合（get_closest_collision_*_fraction）は二分探索の刻み
  （最大長の 1/256 ≒ 4px）でしか求まらないため、相手表面の当たった点から測る。"""
  var axis := Vector2.UP.rotated(global_rotation)
  return clampf((point - global_position).dot(axis), 0.0, desired_length)


func _update_length():
  """長さ更新"""
  var length := _hit_end_length if _hits.size() >= _required_hits() else desired_length

  if length != _current_length:
    _apply_length(length)
    _current_length = length


func _apply_length(length: float) -> void:
  """長さ適用"""
  if ninepatch:
    ninepatch.size.y = length
    ninepatch.position = Vector2(-ninepatch.size.x * 0.5, -length)

  # コリジョン設定（ダメージ判定には使わないが、見た目の長さに合わせておく）
  if shape:
    shape.extents.y = length * 0.5
    var collision_node = $CollisionShape2D
    if collision_node:
      collision_node.position = Vector2(0, -length * 0.5)

  # エフェクト位置更新（子ノードはビームから見て常に上へ伸びる）
  if impact_effect_point:
    impact_effect_point.position = Vector2(0, -length)


func _on_damage_tick() -> void:
  """ダメージ処理（捉えている相手全員）"""
  _play_beam_sound()

  for target in _hits:
    if is_instance_valid(target) and target.is_in_group(target_group):
      if target.has_method("take_damage"):
        target.take_damage(_resolve_damage(target))
        _spawn_impact_effect_at_target(target)


func _resolve_damage(target: Node) -> int:
  """弾（BulletBase._resolve_damage）と同じく、自弾ならプレイヤーの加護の与ダメージ補正を乗せる"""
  if target_group != "enemies":
    return damage
  var player = TargetService.get_player()
  if is_instance_valid(player) and "blessing_container" in player and player.blessing_container:
    return player.blessing_container.process_outgoing_damage(target, damage)
  return damage


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


func cleanup():
  """クリーンアップ処理"""
  if beam_visual_config and beam_visual_config.end_sound and audio_player:
    audio_player.stream = beam_visual_config.end_sound
    audio_player.play()

  _hits.clear()

  queue_free()
