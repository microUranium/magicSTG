extends BlessingBase

## 背水の加護：プレイヤーの残HPが少ないほど与ダメージが増加する（常時型）。
## 残HP割合が floor_ratio（既定0.3=3割）以下で最大(+laststand_max_pct)、満タンで +0%（線形）。
## 体力の減り具合の計算（_low_hp_factor）は BlessingBase にある。
## エンチャント「必死」(laststand_cdr_pct) 装着時は、同じ低HP係数で魔法クールタイムを短縮する。

var _max_pct: float = 1.5
var _cdr_pct: float = 0.0  # 必死：最低HP時のクールタイム短縮率（未装着なら0）


func _recalc_stats() -> void:
  _max_pct = (
    _proto.base_modifiers.get("laststand_max_pct", _max_pct)
    * (1.0 + _sum_pct("laststand_max_pct_pct"))
  )
  _cdr_pct = _sum_pct("laststand_cdr_pct")


func on_equip(_player) -> void:
  _recalc_stats()
  # 装備中であることを示す静的ゲージ（常に満タン・不変）
  init_gauge("durability", 100, 100, _proto.display_name)


func get_damage_bonus_pct(player, _enemy, _ctx: Dictionary) -> float:
  return _max_pct * _low_hp_factor(player)


func get_attack_cooldown_mult(player) -> float:
  if _cdr_pct <= 0.0:  # 必死未装着なら無効（等倍）
    return 1.0
  # 低HPほど短縮。下限(1/60)は AttackCoreBase 側でクランプ。
  return 1.0 - _cdr_pct * _low_hp_factor(player)
