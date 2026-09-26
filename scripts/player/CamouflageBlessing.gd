extends ActiveBlessingBase

## 迷彩の加護：一定時間、敵の照準対象から外れる（アクティブ型）。
## スロット番号キー(1/2/3)で発動。1ステージあたりの使用回数とクールダウンは基底クラスが管理。
##
## 「狙われなくなる」だけで当たり判定は残るため、敵弾に触れれば被弾する。
## 発動時の自機位置を囮座標として TargetService に預け、効果中は
## 自機狙い・追尾・追跡移動がすべてその座標を狙う。

const FADE_ALPHA := 0.4  # 迷彩中の自機スプライトのアルファ
const WARN_BEFORE_SEC := 1.0  # 効果終了の何秒前から点滅予告するか
const WARN_BLINK_INTERVAL := 0.12  # 予告点滅の周期(秒)

var duration_sec: float = 10.0

var _player_ref: Node2D
var _duration_timer: Timer
var _warn_timer: Timer
var _warn_bright: bool = false


func _ready() -> void:
  super._ready()

  _duration_timer = Timer.new()
  _duration_timer.name = "DurationTimer"
  _duration_timer.one_shot = true
  add_child(_duration_timer)
  _duration_timer.timeout.connect(_end_camouflage)
  register_timer(_duration_timer)  # ポーズ中は効果時間も止まる

  _warn_timer = Timer.new()
  _warn_timer.name = "WarnTimer"
  _warn_timer.one_shot = false
  add_child(_warn_timer)
  _warn_timer.timeout.connect(_on_warn_tick)
  register_timer(_warn_timer)


func _recalc_stats() -> void:
  super._recalc_stats()
  duration_sec = _proto.base_modifiers.get("camouflage_duration_sec", duration_sec)
  duration_sec *= 1.0 + _sum_pct("camouflage_duration_pct")


func on_equip(player) -> void:
  _player_ref = player
  super.on_equip(player)


func _on_unequip_impl(_player) -> void:
  if is_active():
    _end_camouflage()


func is_active() -> bool:
  return _duration_timer != null and not _duration_timer.is_stopped()


func can_activate() -> bool:
  # 効果中の再発動は延長も重ね掛けもしない（回数の無駄打ちを防ぐ）
  return super.can_activate() and not is_active()


func _do_activate() -> bool:
  if not is_instance_valid(_player_ref):
    return false

  # 発動位置を囮として登録。以後、敵の照準はこの座標へ向かう。
  TargetService.set_player_targetable(false, _player_ref.global_position)

  if _player_ref.has_method("set_camouflage_visual"):
    _player_ref.set_camouflage_visual(true, FADE_ALPHA)

  _warn_bright = false
  _duration_timer.start(duration_sec)
  _warn_timer.start(WARN_BLINK_INTERVAL)  # 開始直後は _on_warn_tick 側で無視される

  StageSignals.sfx_play_requested.emit("break_shield", _player_ref.global_position, 0.0, 1.2)
  return true


func _end_camouflage() -> void:
  _duration_timer.stop()
  _warn_timer.stop()
  TargetService.set_player_targetable(true)

  if is_instance_valid(_player_ref) and _player_ref.has_method("set_camouflage_visual"):
    _player_ref.set_camouflage_visual(false)


func _on_warn_tick() -> void:
  # 効果終了の直前だけ、アルファを揺らして切れることを知らせる
  if not is_active() or not is_instance_valid(_player_ref):
    return
  if _duration_timer.time_left > WARN_BEFORE_SEC:
    return
  if not _player_ref.has_method("set_camouflage_visual"):
    return

  _warn_bright = not _warn_bright
  _player_ref.set_camouflage_visual(true, FADE_ALPHA * (2.0 if _warn_bright else 1.0))
