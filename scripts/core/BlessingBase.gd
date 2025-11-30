extends GaugeProvider
class_name BlessingBase

signal blessing_updated

var _proto: BlessingItem
var _paused: bool = false
var _managed_timers: Array[Timer] = []  # Timerノードの管理
var item_inst: ItemInstance:
  set(v):
    item_inst = v
    gauge_icon = v.prototype.icon
    _proto = v.prototype as BlessingItem
    _recalc_stats()


func _recalc_stats() -> void:
  pass


func on_equip(_player):
  # プレイヤー装備時に呼ばれる
  pass


func on_unequip(_player):
  # タイマーのクリーンアップ
  _managed_timers.clear()

  # 子クラス固有の処理
  _on_unequip_impl(_player)


func _on_unequip_impl(_player):
  """子クラスでオーバーライド可能"""
  pass


func process_damage(_player, damage):
  # 被弾処理に介入したい場合にオーバーライド
  return damage  # デフォルトはダメージそのまま通す


func set_paused(state: bool) -> void:
  if _paused == state:
    return
  _paused = state

  # 全てのタイマーをポーズ/再開
  _set_timers_paused(state)

  # 子クラス固有の処理（オプション）
  _on_paused_changed(state)


func _on_paused_changed(_paused_state: bool) -> void:
  """子クラスでオーバーライド可能"""
  pass


func is_paused() -> bool:
  """ポーズ状態を取得"""
  return _paused


func register_timer(timer: Timer) -> void:
  """ポーズ管理対象のTimerノードを登録"""
  if timer and not timer in _managed_timers:
    _managed_timers.append(timer)


func _set_timers_paused(paused: bool) -> void:
  """全てのタイマーをポーズ/再開"""
  # Timerノードのポーズ制御
  for timer in _managed_timers:
    if is_instance_valid(timer):
      timer.paused = paused


#---------------------------------------------------------------------
# Internal Helpers
#---------------------------------------------------------------------
func _sum_pct(key: String) -> float:
  var t := 0.0
  for enc in item_inst.enchantments:
    var modifiers := enc.get_modifiers(item_inst.enchantments[enc])
    t += modifiers.get(key, 0.0)
  return t


func _sum_add(key: String) -> float:
  var t := 0.0
  for enc in item_inst.enchantments:
    var modifiers := enc.get_modifiers(item_inst.enchantments[enc])
    t += modifiers.get(key, 0)
  return t


func _ready() -> void:
  super._ready()
  add_to_group("blessings")
