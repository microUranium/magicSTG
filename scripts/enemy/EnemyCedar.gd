extends EnemyBase
class_name EnemyCedar

## 通常攻撃はせず、HP が一定割合減るたびに花粉（AttackCoreSlot のパターン）をばらまく。
## 一度の被弾で複数の区切りを越えた場合は越えた回数分ばらまき、撃破時（HP 0）も最後の1回としてばらまく。

@export var burst_steps: int = 5  # HP を何等分した区切りごとにばらまくか（5 = 20% ごと）

var _bursts_fired: int = 0


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  _scatter_pollen_for_lost_hp(current_hp, max_hp)
  super.on_hp_changed(current_hp, max_hp)


func _scatter_pollen_for_lost_hp(current_hp: int, max_hp: int) -> void:
  var reached := _count_reached_steps(current_hp, max_hp)
  while _bursts_fired < reached:
    _bursts_fired += 1
    if slot:
      slot.trigger_all_cores()


func _count_reached_steps(current_hp: int, max_hp: int) -> int:
  if max_hp <= 0 or burst_steps <= 0:
    return 0
  var lost := clampi(max_hp - current_hp, 0, max_hp)
  # 割り切れる場合は浮動小数でも誤差なく整数になるので、20% ちょうどで区切りを越えたと判定できる
  return floori(float(lost * burst_steps) / max_hp)
