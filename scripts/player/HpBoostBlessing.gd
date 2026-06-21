extends BlessingBase

## 体力増強の加護：装備するとプレイヤーの最大HPが増加する（常時型）。
## 割合(hp_pct)は基底の最大HPをベースに加算する。

var player_ref
var _orig_max: int = 0
var _bonus: int = 0
var _applied: bool = false


func _recalc_stats() -> void:
  if player_ref == null or player_ref.hp_node == null:
    return
  var base: int = _orig_max if _applied else player_ref.hp_node.max_hp
  var pct: float = _sum_pct("hp_pct")
  var flat: float = float(_proto.base_modifiers.get("hp_add", 0)) + _sum_add("hp_add")
  _bonus = int(round(base * pct)) + int(flat)


func on_equip(player) -> void:
  player_ref = player
  # 装備中であることを示す静的ゲージ（常に満タン・不変）
  init_gauge("durability", 100, 100, _proto.display_name)
  # 子ノードの装備は Player._ready より先行し hp_node(@onready) 未確定のため遅延適用
  if player_ref.is_node_ready():
    _apply()
  else:
    player_ref.ready.connect(_apply)


func _apply() -> void:
  if _applied:
    return
  _orig_max = player_ref.hp_node.max_hp
  _recalc_stats()
  player_ref.hp_node.set_max_hp(_orig_max + _bonus)
  player_ref.hp_node.heal(_bonus)  # 増えた枠を満タンで開始
  _applied = true


func _on_unequip_impl(_player) -> void:
  if _applied and is_instance_valid(player_ref) and player_ref.hp_node:
    player_ref.hp_node.set_max_hp(_orig_max)
  _applied = false
