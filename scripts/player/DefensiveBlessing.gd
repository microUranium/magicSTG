extends BlessingBase

signal shield_broken
signal shield_recovered
signal shield_damaged

var shield_max: int = 50
var shield_current: int = 50
var recover_delay: float = 5.0
var is_broken: bool = false

var player_ref
@onready var shield_sprite = get_node_or_null("ShieldSprite")


func _recalc_stats() -> void:
  # BlessingItem 側の base_modifiers を取り込み
  shield_max = _proto.base_modifiers.shield_hp + int(_sum_add("shield_hp_add"))
  shield_max = int(shield_max * (1.0 + _sum_pct("shield_hp_pct")))
  recover_delay = (
    _proto.base_modifiers.shield_recover_delay * (1.0 + _sum_pct("shield_recover_delay_pct"))
  )

  # 値が変わったらゲージ刷新
  shield_current = shield_max
  init_gauge("durability", shield_max, shield_current, _proto.display_name)
  emit_signal("blessing_updated")


func on_equip(player):
  player_ref = player
  _recalc_stats()

  shield_current = shield_max
  is_broken = false

  # プレイヤー被弾シグナルへ接続
  if not player_ref.is_connected("damage_received", Callable(self, "on_player_damaged")):
    player_ref.connect("damage_received", Callable(self, "on_player_damaged"))

  # プレイヤーにシールドスプライトを配置する場合
  if shield_sprite:
    player.add_child(shield_sprite)
    shield_sprite.global_position = player.global_position
    shield_sprite.play("idle")

  # 汎用ゲージの初期化
  init_gauge("durability", shield_max, shield_current, "防壁の加護")


func on_unequip(_player):
  if player_ref and player_ref.is_connected("damage_received", Callable(self, "on_player_damaged")):
    player_ref.disconnect("damage_received", Callable(self, "on_player_damaged"))
  shield_sprite.queue_free()


func _process(_delta):
  if shield_sprite and player_ref:
    shield_sprite.global_position = player_ref.global_position


func process_damage(_player, damage):
  if is_broken:
    return damage
  else:
    on_player_damaged(damage)
    return 0


func on_player_damaged(damage):
  if is_broken:
    return  # シールド破壊時は介入しない

  shield_current -= damage
  set_gauge(shield_current)  # 汎用ゲージの値を更新
  emit_signal("shield_damaged", shield_current, shield_max)

  if shield_current > 0:
    if shield_sprite:
      shield_sprite.play("hit")
    StageSignals.sfx_play_requested.emit("hit_shield", player_ref.global_position, 0, 1.0)
    get_tree().create_timer(0.1).connect("timeout", Callable(self, "_return_to_idle"))
  else:
    shield_current = 0
    is_broken = true
    if shield_sprite:
      shield_sprite.play("break")
    StageSignals.sfx_play_requested.emit("break_shield", player_ref.global_position, 0, 1.0)
    emit_signal("shield_broken")
    # 復活タイマー起動
    get_tree().create_timer(recover_delay).connect("timeout", Callable(self, "recover_shield"))


func recover_shield():
  shield_current = shield_max
  set_gauge(shield_current)  # 汎用ゲージの値を更新
  is_broken = false
  if shield_sprite:
    shield_sprite.play("recover")
  get_tree().create_timer(0.1).connect("timeout", Callable(self, "_return_to_idle"))
  emit_signal("shield_recovered")


func _return_to_idle():
  if not is_broken:
    shield_sprite.play("idle")
