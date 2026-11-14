extends ActiveBlessingBase

## 時界の加護：クールタイムが溜まるとキーで発動できる（使用回数の制限はない）。
##   発動     : 結界の範囲内の敵弾を消し、自機についていく結界を張る
##   効果中   : 結界に入った敵弾は時間の進み方が SLOW_TIME_SCALE（-95%）になり、出ると元に戻る
##   効果終了 : 結界の範囲内の敵弾を消し、結界を消す。その後クールタイムが 0 から始まる
## ゲージ（cooldown 表示）: クールタイム中は溜まり、準備完了で満タン、効果中は減っていく（ビームと同じ）。
## 弾は爆発させずに消す（自機のすぐ近くで消すため、敵弾の爆発に巻き込まれないように）。
##
## base_modifiers（エンチャントで増減できるよう、値はすべてここから読む）:
##   blessing_cooldown_sec  : クールタイム（× (1 + blessing_cooldown_pct)＝速復）
##   spacetime_duration_sec : 効果時間（× (1 + blessing_duration_pct)＝持続）
##   spacetime_radius       : 結界の半径（(+ spacetime_radius_add) × (1 + blessing_area_pct)＝広範）

signal field_started
signal field_ended

enum State { COOLING, READY, ACTIVE }

const FIELD_EFFECT := preload("res://scripts/effects/SpacetimeFieldEffect.gd")
const SLOW_TIME_SCALE := 0.05  # 結界内の敵弾の時間の進み方（-95%）
const ENEMY_BULLET_GROUP := "players"  # 敵弾の target_group
## 弾を探すコリジョンマスク。弾の多くはレイヤー2だが、敵シーンに埋め込まれた弾
## （ゴースト・スパイク・沼の鳥など）はレイヤー未設定＝1 のため、1 と 2 の両方を見る。
## 敵（レイヤー3）や自機（レイヤー1）も引っかかるが、_is_enemy_bullet() で敵弾だけに絞る。
const BULLET_DETECT_MASK := 1 | 2
const ACTIVATION_SFX := "activation_blessing_spacetime"  # 発動時の効果音（SFX_Catalog の名前）

var cooldown_total: float = 40.0
var duration_sec: float = 7.0
var radius: float = 200.0

var _state: State = State.COOLING
var _player_ref: Node2D
var _recharge_timer: Timer
var _duration_timer: Timer
var _field: Area2D
var _field_shape: CircleShape2D
var _slowed: Array[Node] = []  # 結界内で遅くしている敵弾
var _effect: CanvasLayer = null


func _ready() -> void:
  super._ready()

  _recharge_timer = Timer.new()
  _recharge_timer.name = "RechargeTimer"
  _recharge_timer.one_shot = true
  add_child(_recharge_timer)
  _recharge_timer.timeout.connect(_on_recharged)
  register_timer(_recharge_timer)

  _duration_timer = Timer.new()
  _duration_timer.name = "DurationTimer"
  _duration_timer.one_shot = true
  add_child(_duration_timer)
  _duration_timer.timeout.connect(_end_field)
  register_timer(_duration_timer)

  _field = Area2D.new()
  _field.name = "Field"
  _field.collision_layer = 0
  _field.collision_mask = BULLET_DETECT_MASK
  _field.monitorable = false
  _field.monitoring = false
  _field_shape = CircleShape2D.new()
  var col := CollisionShape2D.new()
  col.shape = _field_shape
  _field.add_child(col)
  add_child(_field)
  _field.area_entered.connect(_on_area_entered_field)
  _field.area_exited.connect(_on_area_exited_field)


func _recalc_stats() -> void:
  var mods: Dictionary = _proto.base_modifiers
  cooldown_total = (
    float(mods.get("blessing_cooldown_sec", cooldown_total))
    * (1.0 + _sum_pct("blessing_cooldown_pct"))
  )
  duration_sec = (
    float(mods.get("spacetime_duration_sec", duration_sec))
    * (1.0 + _sum_pct("blessing_duration_pct"))
  )
  radius = (
    (float(mods.get("spacetime_radius", radius)) + _sum_add("spacetime_radius_add"))
    * (1.0 + _sum_pct("blessing_area_pct"))
  )


func on_equip(player) -> void:
  # 使用回数制の基底（ActiveBlessingBase.on_equip）は使わない
  _player_ref = player
  _recalc_stats()
  _field_shape.radius = radius
  init_gauge("cooldown", 100.0, 0.0, _proto.display_name)
  _start_recharge()  # ステージ開始時は 0 から溜める


func _on_unequip_impl(_player) -> void:
  if _state == State.ACTIVE:
    _stop_field(false)


func can_activate() -> bool:
  return not _paused and _state == State.READY


func activate() -> bool:
  if not can_activate() or not is_instance_valid(_player_ref):
    emit_signal("activation_failed")
    return false
  _start_field()
  emit_signal("activated", -1)  # 使用回数の制限はない
  return true


func is_active() -> bool:
  return _state == State.ACTIVE


func get_state() -> State:
  return _state


#---------------------------------------------------------------------
# ゲージ・状態
#---------------------------------------------------------------------
func _process(_delta: float) -> void:
  match _state:
    State.COOLING:
      if cooldown_total > 0.0:
        set_gauge((1.0 - _recharge_timer.time_left / cooldown_total) * 100.0)
    State.READY:
      set_gauge(100.0)
    State.ACTIVE:
      if duration_sec > 0.0:
        set_gauge(_duration_timer.time_left / duration_sec * 100.0)
      _follow_player()


func _start_recharge() -> void:
  _state = State.COOLING
  set_gauge(0.0)
  if cooldown_total <= 0.0:
    _on_recharged()
    return
  _recharge_timer.start(cooldown_total)


func _on_recharged() -> void:
  _state = State.READY
  set_gauge(100.0)


#---------------------------------------------------------------------
# 結界
#---------------------------------------------------------------------
func _start_field() -> void:
  _state = State.ACTIVE
  _field_shape.radius = radius
  _follow_player()
  _vanish_enemy_bullets_in_radius()
  _field.set_deferred("monitoring", true)
  _duration_timer.start(duration_sec)
  _start_effect()
  StageSignals.sfx_play_requested.emit(ACTIVATION_SFX, _player_ref.global_position, 0.0, 1.0)
  set_gauge(100.0)
  field_started.emit()


func _end_field() -> void:
  _stop_field(true)
  _start_recharge()


func _stop_field(vanish_inside: bool) -> void:
  """結界を消す。vanish_inside なら範囲内の敵弾を消してから消す"""
  _follow_player()
  if vanish_inside:
    _vanish_enemy_bullets_in_radius()
  for bullet in _slowed:
    if is_instance_valid(bullet):
      bullet.set_time_scale(1.0)
  _slowed.clear()
  _field.set_deferred("monitoring", false)
  _duration_timer.stop()
  if is_instance_valid(_effect):
    _effect.finish()
  _effect = null
  field_ended.emit()


func _follow_player() -> void:
  if not is_instance_valid(_player_ref):
    return
  _field.global_position = _player_ref.global_position
  if is_instance_valid(_effect):
    _effect.set_center(
      _player_ref.get_global_transform_with_canvas().origin,
      _player_ref.get_viewport().get_visible_rect().size
    )


func _is_enemy_bullet(area: Node) -> bool:
  return area is BulletBase and area.target_group == ENEMY_BULLET_GROUP


func _on_area_entered_field(area: Area2D) -> void:
  if not _is_enemy_bullet(area) or area.is_queued_for_deletion():
    return
  area.set_time_scale(SLOW_TIME_SCALE)
  if area not in _slowed:
    _slowed.append(area)


func _on_area_exited_field(area: Area2D) -> void:
  if area in _slowed:
    _slowed.erase(area)
    if is_instance_valid(area):
      area.set_time_scale(1.0)


func _vanish_enemy_bullets_in_radius() -> void:
  """自機を中心に半径 radius の範囲内の敵弾を、爆発させずに消す。
  結界の Area2D は有効化直後に重なりが取れないため、物理空間に直接問い合わせる。"""
  if not is_instance_valid(_player_ref):
    return
  var space := _player_ref.get_world_2d().direct_space_state
  var shape := CircleShape2D.new()
  shape.radius = radius
  var query := PhysicsShapeQueryParameters2D.new()
  query.shape = shape
  query.transform = Transform2D(0.0, _player_ref.global_position)
  query.collision_mask = BULLET_DETECT_MASK
  query.collide_with_areas = true
  query.collide_with_bodies = false
  for hit in space.intersect_shape(query, 2048):
    var area = hit.get("collider")
    if is_instance_valid(area) and _is_enemy_bullet(area) and not area.is_queued_for_deletion():
      _slowed.erase(area)
      area.vanish()


#---------------------------------------------------------------------
# 背景の演出
#---------------------------------------------------------------------
func _start_effect() -> void:
  var scene_root := get_tree().current_scene if get_tree() else null
  if scene_root == null:
    return
  _effect = FIELD_EFFECT.new()
  scene_root.add_child(_effect)
  _effect.start(radius)
  _follow_player()
