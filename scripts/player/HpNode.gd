extends Node

signal hp_changed(current_hp, max_hp)
signal extra_hp_changed(extra_hp, extra_hp_max)

@export var max_hp: int = 10
var current_hp: int

## 追加の体力（エンチャント「庇護」）。current_hp とは別枠で max_hp を超えて持てる。
## 被弾時は先にこちらから減り、回復（heal）では増えない。
var extra_hp: int = 0
var extra_hp_max: int = 0  # 付与時の量（HPバーの表示基準）


func _ready():
  current_hp = max_hp
  emit_signal("hp_changed", current_hp, max_hp)


func take_damage(amount: int = 1):
  if amount > 0 and extra_hp > 0:
    var absorbed: int = mini(extra_hp, amount)
    extra_hp -= absorbed
    amount -= absorbed
    emit_signal("extra_hp_changed", extra_hp, extra_hp_max)

  current_hp -= amount
  if current_hp < 0:
    current_hp = 0
  emit_signal("hp_changed", current_hp, max_hp)


func heal(amount: int = 1):
  current_hp += amount
  if current_hp > max_hp:
    current_hp = max_hp
  emit_signal("hp_changed", current_hp, max_hp)


func set_max_hp(value: int):
  max_hp = value
  current_hp = min(current_hp, max_hp)
  emit_signal("hp_changed", current_hp, max_hp)


## 追加の体力を付与する（残量と表示基準を同じ値にする）。0 で解除。
func set_extra_hp(value: int) -> void:
  extra_hp = maxi(0, value)
  extra_hp_max = extra_hp
  emit_signal("extra_hp_changed", extra_hp, extra_hp_max)


## 通常の体力と追加の体力の合計（致命傷の判定に使う）
func get_total_hp() -> int:
  return current_hp + extra_hp
