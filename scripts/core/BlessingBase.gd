extends GaugeProvider
class_name BlessingBase

signal blessing_updated
signal free_use_triggered  # 幸運：使用回数を消費せずに発動した

const LOW_HP_FLOOR_RATIO_DEFAULT := 0.3  # 体力の減り具合が最大になる残HP割合の既定値

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


func process_fatal_damage(_player, _damage) -> bool:
  # 他の加護をすべて通した後、そのダメージで HP が 0 になる場合にだけ呼ばれる。
  # true を返すとダメージが無効化される（不屈の加護による復活など）。
  return false


func get_damage_bonus_pct(_player, _enemy, _ctx: Dictionary) -> float:
  # 自弾が敵にヒットした時の与ダメージボーナス率を返す（0.5 = +50%）。
  # 複数加護の戻り値は BlessingContainer 側で加算合成され、基底値に一括適用される。
  return 0.0


func get_attack_cooldown_mult(_player) -> float:
  # プレイヤーの魔法クールタイムへの倍率を返す（1.0 = 等倍, 0.5 = 半減）。
  # 複数加護の戻り値は BlessingContainer 側で乗算合成される。
  return 1.0


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


static func _roll_chance(chance: float) -> bool:
  """確率 chance（0.0〜1.0）で true を返す"""
  if chance <= 0.0:
    return false
  # randf() は 1.0 を含みうるため、確率 1.0 以上は乱数を使わず確定させる
  return chance >= 1.0 or randf() < chance


func _roll_free_use() -> bool:
  """エンチャント「幸運」：使用回数を消費しないなら true を返す"""
  if _roll_chance(_sum_pct("blessing_free_use_chance_pct")):
    free_use_triggered.emit()
    return true
  return false


func _low_hp_floor_ratio() -> float:
  """残HP割合がこれ以下で「体力の減り具合」が最大(1)になる"""
  if _proto == null:
    return LOW_HP_FLOOR_RATIO_DEFAULT
  return _proto.base_modifiers.get("laststand_floor_ratio", LOW_HP_FLOOR_RATIO_DEFAULT)


func _low_hp_factor_from(current_hp: int, max_hp: int) -> float:
  """体力の減り具合（満タン=0、floor_ratio 以下=1、間は線形）"""
  if max_hp <= 0:
    return 0.0
  var ratio := float(current_hp) / float(max_hp)
  var denom := 1.0 - _low_hp_floor_ratio()
  if denom <= 0.0:
    return 1.0
  return clampf((1.0 - ratio) / denom, 0.0, 1.0)


func _low_hp_factor(player) -> float:
  """プレイヤーの現在HPから体力の減り具合を求める"""
  if not is_instance_valid(player) or player.hp_node == null:
    return 0.0
  return _low_hp_factor_from(player.hp_node.current_hp, player.hp_node.max_hp)


func _ready() -> void:
  super._ready()
  add_to_group("blessings")
