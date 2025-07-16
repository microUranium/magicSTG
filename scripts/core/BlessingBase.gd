extends GaugeProvider
class_name BlessingBase

signal blessing_updated

var _proto: BlessingItem
var item_inst: ItemInstance:
  set(v):
    item_inst = v
    _proto = v.prototype as BlessingItem
    _recalc_stats()


func _recalc_stats() -> void:
  pass


func on_equip(_player):
  # プレイヤー装備時に呼ばれる
  pass


func on_unequip(_player):
  # プレイヤーから外れた時に呼ばれる
  pass


func process_damage(_player, damage):
  # 被弾処理に介入したい場合にオーバーライド
  return damage  # デフォルトはダメージそのまま通す


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
