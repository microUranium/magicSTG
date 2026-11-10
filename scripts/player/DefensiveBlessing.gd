extends BlessingBase

signal shield_broken
signal shield_recovered
signal shield_damaged

var shield_max: int = 50
var shield_current: int = 50
var recover_delay: float = 5.0
var is_broken: bool = false
var damage_taken_pct: float = 0.0  # 緩衝：シールドが受けるダメージの増減率（負で軽減）

# === 自然回復（破壊されていない時） ===
var regen_delay: float = 10.0  # 最後の被弾から回復開始までの秒数
var regen_rate: float = 2.0  # 回復速度(HP/秒)
var _time_since_damage: float = 0.0  # 最後の被弾からの経過時間
var _regen_accumulator: float = 0.0  # int化のための端数蓄積
var _recover_elapsed: float = 0.0  # 破壊後の復活ゲージ用 経過時間(delta積算)

var player_ref
var recover_timer: Timer
@onready var shield_sprite = get_node_or_null("ShieldSprite")


func _ready() -> void:
  super._ready()

  # RecoverTimerの初期化（シーンから取得するか、動的に作成）
  recover_timer = get_node_or_null("RecoverTimer")
  if not recover_timer:
    recover_timer = Timer.new()
    recover_timer.name = "RecoverTimer"
    add_child(recover_timer)


func _recalc_stats() -> void:
  # BlessingItem 側の base_modifiers を取り込み
  shield_max = _proto.base_modifiers.shield_hp + int(_sum_add("shield_hp_add"))
  shield_max = int(shield_max * (1.0 + _sum_pct("shield_hp_pct")))
  recover_delay = (
    _proto.base_modifiers.shield_recover_delay * (1.0 + _sum_pct("shield_recover_delay_pct"))
  )
  regen_delay = _proto.base_modifiers.get("shield_regen_delay", regen_delay)
  regen_rate = _proto.base_modifiers.get("shield_regen_rate", regen_rate)
  damage_taken_pct = _sum_pct("shield_damage_taken_pct")

  # 値が変わったらゲージ刷新
  shield_current = shield_max
  init_gauge("durability", shield_max, shield_current, _proto.display_name)
  emit_signal("blessing_updated")


func on_equip(player):
  player_ref = player
  _recalc_stats()

  shield_current = shield_max
  is_broken = false

  # RecoverTimerのセットアップ
  recover_timer.one_shot = true
  recover_timer.timeout.connect(recover_shield)
  register_timer(recover_timer)  # ポーズ管理に登録

  # 被弾は BlessingContainer 経由の process_damage() だけで受ける。
  # Player.damage_received にも接続すると、加護処理後の damage=0 で二重に処理が走る。

  # プレイヤーにシールドスプライトを配置する場合
  if shield_sprite:
    player.add_child(shield_sprite)
    shield_sprite.global_position = player.global_position
    shield_sprite.play("idle")

  # 汎用ゲージの初期化
  init_gauge("durability", shield_max, shield_current, "防壁の加護")


func on_unequip(_player):
  shield_sprite.queue_free()


func _process(delta):
  if shield_sprite and player_ref:
    shield_sprite.global_position = player_ref.global_position

  if _paused:  # ポーズ中は回復・ゲージ更新を止める
    return

  if is_broken:
    _update_recover_gauge(delta)
  else:
    _process_regen(delta)


func _update_recover_gauge(delta: float) -> void:
  # 破壊中：delta を積算し、復活までの経過時間でゲージを 0→max に滑らかに充填（A案・時間連動）
  if recover_delay <= 0.0:
    return
  _recover_elapsed += delta
  var ratio: float = clamp(_recover_elapsed / recover_delay, 0.0, 1.0)
  set_gauge(shield_max * ratio)


func _process_regen(delta: float) -> void:
  # 自然回復：最後の被弾から regen_delay 秒経過後、regen_rate(HP/秒) で徐々に回復
  _time_since_damage += delta
  if shield_current >= shield_max or _time_since_damage < regen_delay:
    return

  _regen_accumulator += regen_rate * delta
  if _regen_accumulator < 1.0:
    return

  var add: int = int(_regen_accumulator)
  _regen_accumulator -= add
  shield_current = min(shield_current + add, shield_max)
  set_gauge(shield_current)


func process_damage(_player, damage):
  if is_broken:
    return damage
  else:
    _apply_shield_damage(reduce_shield_damage(damage, damage_taken_pct, randf()))
    return 0


## 緩衝：シールドが受けるダメージを pct（負で軽減）だけ増減する。
## 端数は小数部分の確率で切り上げるため、期待値は damage * (1 + pct) に一致する。
## （ダメージ1の弾も確率で0になる）roll は 0.0〜1.0 の乱数で、テストでは固定値を渡す。
static func reduce_shield_damage(damage: int, pct: float, roll: float) -> int:
  if damage <= 0 or pct >= 0.0:
    return damage
  # 5 * (1 - 0.2) = 4.0000000000000002 のような浮動小数の誤差で端数が生じないよう丸める
  var x := snappedf(damage * (1.0 + maxf(pct, -1.0)), 0.000001)
  var base := int(floor(x))
  return base + (1 if roll < x - base else 0)


func _apply_shield_damage(damage):
  if _paused:  # ポーズ中は処理しない
    return

  if is_broken:
    return  # シールド破壊時は介入しない

  _time_since_damage = 0.0  # 被弾したので自然回復の待機をリセット
  _regen_accumulator = 0.0
  shield_current -= damage
  set_gauge(shield_current)  # 汎用ゲージの値を更新
  emit_signal("shield_damaged", shield_current, shield_max)

  if shield_current > 0:
    if shield_sprite:
      shield_sprite.play("hit")
    StageSignals.sfx_play_requested.emit("hit_shield", player_ref.global_position, 0, 1.0)
    get_tree().create_timer(0.1, false).connect("timeout", Callable(self, "_return_to_idle"))
  else:
    shield_current = 0
    is_broken = true
    if shield_sprite:
      shield_sprite.play("break")
    StageSignals.sfx_play_requested.emit("break_shield", player_ref.global_position, 0, 1.0)
    emit_signal("shield_broken")
    # 復活ゲージを無効化画像へ切替
    _recover_elapsed = 0.0
    set_gauge_style("durability_recovering")
    set_gauge(0)
    # 復活タイマー起動（Timerノードを使用）
    recover_timer.wait_time = recover_delay
    recover_timer.start()


func recover_shield():
  # Timerノードが自動的にポーズを管理するため、ポーズチェック不要
  shield_current = shield_max
  is_broken = false
  _time_since_damage = 0.0
  _regen_accumulator = 0.0
  # ゲージ画像を通常へ戻す
  set_gauge_style("durability")
  set_gauge(shield_current)  # 汎用ゲージの値を更新
  if shield_sprite:
    shield_sprite.play("recover")
  get_tree().create_timer(0.1, false).connect("timeout", Callable(self, "_return_to_idle"))
  emit_signal("shield_recovered")


func _return_to_idle():
  if _paused:  # ポーズ中は処理しない
    return
  if not is_broken and shield_sprite:
    shield_sprite.play("idle")
