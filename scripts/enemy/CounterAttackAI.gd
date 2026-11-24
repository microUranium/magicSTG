extends EnemyAIBase
class_name CounterAttackAI

@export var counter_sfx: String = "hit_wood"
## 反撃のクールタイム（秒）。反撃してからこの時間が過ぎるまでは、被弾しても反撃しない（効果音も鳴らさない）。
## 0 なら被弾のたびに反撃する。コアの発射はクールタイムを無視する強制発射なので、ここで間引く
@export var counter_cooldown_sec: float = 0.0

var _cooldown_left: float = 0.0


func _ready():
  super._ready()

  if enemy_node:
    enemy_node.connect("received_damage", _on_received_damage)


func _process(delta: float) -> void:
  # ポーズ中は _process が止まるので、クールタイムも進まない
  if _cooldown_left > 0.0:
    _cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _on_received_damage(_amount: int, _is_invincible: bool):
  if _cooldown_left > 0.0:
    return
  if is_instance_valid(attack_core_slot):
    _cooldown_left = counter_cooldown_sec
    StageSignals.emit_signal("sfx_play_requested", counter_sfx, enemy_node.global_position, 0, 0)
    attack_core_slot.trigger_all_cores()
