extends BlessingBase

## 近接の加護：自弾が敵にヒットした時、対象とプレイヤーの距離が近いほど与ダメージが増加する（常時型）。
## 距離0で +proximity_max_pct、proximity_range 以遠で +0%（線形）。

var _max_pct: float = 0.5
var _range: float = 300.0


func _recalc_stats() -> void:
  _max_pct = (
    _proto.base_modifiers.get("proximity_max_pct", _max_pct)
    * (1.0 + _sum_pct("proximity_max_pct_pct"))
  )
  _range = _proto.base_modifiers.get("proximity_range", _range) + _sum_add("proximity_range_add")


func on_equip(_player) -> void:
  _recalc_stats()
  # 装備中であることを示す静的ゲージ（常に満タン・不変）
  init_gauge("durability", 100, 100, _proto.display_name)


func get_damage_bonus_pct(player, enemy, _ctx: Dictionary) -> float:
  if not (is_instance_valid(player) and is_instance_valid(enemy)):
    return 0.0
  if _range <= 0.0:
    return 0.0
  var dist: float = player.global_position.distance_to(enemy.global_position)
  var t := clampf(1.0 - dist / _range, 0.0, 1.0)  # 近いほど 1
  return _max_pct * t
