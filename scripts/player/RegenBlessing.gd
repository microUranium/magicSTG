extends BlessingBase

## 回復の加護：一定間隔で体力を回復する（常時型）。
## エンチャント
##   速治 (regen_interval_sec_pct)   : 回復の間隔を短縮
##   危癒 (regen_low_hp_interval_pct): 体力が少ないほど回復の間隔を短縮（体力の減り具合で線形）
##   応急 (regen_on_hit_chance_pct)  : 被弾時に確率で heal_amount を即時回復

signal healing_done
signal on_hit_healed(amount: int)  # 応急による即時回復

const MIN_LOW_HP_INTERVAL_SEC := 0.2  # 危癒で短縮したときの回復間隔の下限

@export var heal_amount: int = 1
@export var heal_interval: float = 1.0  # 現在の回復間隔（危癒で変動する）
var player_ref
var _healable: bool = false
var _cooling: bool = false
var heal_timer: Timer

var _base_interval: float = 1.0  # 速治まで適用した回復間隔
var _low_hp_interval_pct: float = 0.0  # 危癒：体力最低時の回復間隔の短縮率
var _low_hp_factor_now: float = 0.0  # 直近の hp_changed から求めた体力の減り具合
var _on_hit_chance: float = 0.0  # 応急：被弾時に即時回復する確率


func _ready() -> void:
  super._ready()

  # HealTimerの初期化（シーンから取得するか、動的に作成）
  heal_timer = get_node_or_null("HealTimer")
  if not heal_timer:
    heal_timer = Timer.new()
    heal_timer.name = "HealTimer"
    add_child(heal_timer)


func on_equip(player):
  heal_amount = _proto.base_modifiers.get("regen_amount", heal_amount)
  _base_interval = (
    _proto.base_modifiers.get("regen_interval_sec", heal_interval)
    * (1.0 + _sum_pct("regen_interval_sec_pct"))
  )
  _low_hp_interval_pct = _sum_pct("regen_low_hp_interval_pct")
  _on_hit_chance = _sum_pct("regen_on_hit_chance_pct")
  heal_interval = _current_interval()

  player_ref = player
  _recalc_stats()

  player_ref.ready.connect(_connect_signals)
  if (
    _on_hit_chance > 0.0
    and player_ref.has_signal("damage_received")
    and not player_ref.damage_received.is_connected(_on_player_damaged)
  ):
    player_ref.damage_received.connect(_on_player_damaged)

  heal_timer.timeout.connect(_on_heal_tick)
  register_timer(heal_timer)  # ポーズ管理対象として登録
  heal_timer.start(heal_interval)
  _cooling = true

  # 汎用ゲージの初期化
  init_gauge("cooldown", 100, 0, _proto.display_name)


func _on_unequip_impl(_player) -> void:
  if (
    player_ref
    and player_ref.has_signal("damage_received")
    and player_ref.damage_received.is_connected(_on_player_damaged)
  ):
    player_ref.damage_received.disconnect(_on_player_damaged)


func _connect_signals():
  player_ref.hp_node.connect("hp_changed", Callable(self, "_on_hp_changed"))


func _process(_delta: float) -> void:
  if heal_timer:
    var elapsed = heal_timer.time_left
    set_gauge((heal_interval - elapsed) * 100 / heal_interval)  # 残り時間をゲージに反映

  if player_ref and _healable and not _cooling:
    _do_heal()
    _start_cooldown()


func _on_heal_tick() -> void:
  heal_timer.stop()
  _cooling = false


func _do_heal() -> void:
  if player_ref and _healable:
    player_ref.emit_signal("healing_received", heal_amount)
    emit_signal("healing_done", heal_amount)


func _start_cooldown() -> void:
  _cooling = true
  # start(秒) は wait_time を書き換えるため、毎回現在の間隔を明示して始める
  heal_timer.start(heal_interval)
  set_gauge(0)  # ゲージをリセット


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
  if current_hp < max_hp:
    _healable = true
  else:
    _healable = false

  if _low_hp_interval_pct > 0.0:
    _low_hp_factor_now = _low_hp_factor_from(current_hp, max_hp)
    _update_interval()


#---------------------------------------------------------------------
# 危癒：体力に応じた回復間隔
#---------------------------------------------------------------------
func _current_interval() -> float:
  if _low_hp_interval_pct <= 0.0:
    return _base_interval
  var reduced := _base_interval * (1.0 - _low_hp_interval_pct * _low_hp_factor_now)
  # 下限は危癒による短縮にだけ効かせる（元の間隔が下限より短い場合は元の間隔のまま）
  return maxf(reduced, minf(_base_interval, MIN_LOW_HP_INTERVAL_SEC))


func _update_interval() -> void:
  var new_interval := _current_interval()
  if is_equal_approx(new_interval, heal_interval):
    return

  if _cooling and heal_timer and not heal_timer.is_stopped():
    # 待機の途中なら、進んだ割合を保ったまま残り時間を新しい間隔で計算し直す
    var progress := clampf(1.0 - heal_timer.time_left / heal_interval, 0.0, 1.0)
    heal_interval = new_interval
    heal_timer.start(maxf((1.0 - progress) * new_interval, 0.001))
  else:
    heal_interval = new_interval


#---------------------------------------------------------------------
# 応急：被弾時の即時回復
#---------------------------------------------------------------------
func _on_player_damaged(damage) -> void:
  # 体力が実際に減った被弾だけが対象（シールドが受け止めた damage=0 などは除外）
  if _paused or damage <= 0:
    return
  if _roll_chance(_on_hit_chance):
    # Player は damage_received を発火してから HP を減らすため、
    # 被弾の反映後に回復する（先に回復すると満タン時に無駄になり、致命傷も耐えてしまう）
    call_deferred("_heal_on_hit")


func _heal_on_hit() -> void:
  if not is_instance_valid(player_ref):
    return
  var hp = player_ref.get("hp_node")
  if hp == null or hp.current_hp <= 0:  # 被弾でやられていたら回復しない
    return
  player_ref.emit_signal("healing_received", heal_amount)
  emit_signal("on_hit_healed", heal_amount)
