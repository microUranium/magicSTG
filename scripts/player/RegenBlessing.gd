extends BlessingBase

signal healing_done

@export var heal_amount: int = 1
@export var heal_interval: float = 1.0
var player_ref
var _healable: bool = false
var _cooling: bool = false
var heal_timer: Timer


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
  heal_interval = (
    _proto.base_modifiers.get("regen_interval_sec", heal_interval)
    * (1.0 + _sum_pct("regen_interval_sec_pct"))
  )

  player_ref = player
  _recalc_stats()

  player_ref.ready.connect(_connect_signals)

  heal_timer.wait_time = heal_interval
  heal_timer.timeout.connect(_on_heal_tick)
  register_timer(heal_timer)  # ポーズ管理対象として登録
  heal_timer.start()
  _cooling = true

  # 汎用ゲージの初期化
  init_gauge("cooldown", 100, 0, _proto.display_name)


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
  heal_timer.start()
  set_gauge(0)  # ゲージをリセット


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
  if current_hp < max_hp:
    _healable = true
  else:
    _healable = false
