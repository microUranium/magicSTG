extends Node
class_name EnemyAIBase

@export var base_speed: float = 100.0
@export var attack_core_slot: UniversalAttackCoreSlot = null  # 攻撃コアをセットするスロット

var enemy_node: Node2D

var _pattern_cores: Array[UniversalAttackCore] = []
var core_scene: PackedScene = preload("res://scenes/attackCores/universal_attack_core.tscn")


func _ready():
  enemy_node = get_parent()
  if enemy_node == null:
    push_warning("EnemyAI.gd: 親Node2Dが存在しません。")


func set_attack_patterns(patterns: Array[AttackPattern]):
  """攻撃パターンを汎用コアに設定"""
  var needed_cores = patterns.size()
  var current_cores = _pattern_cores.size()

  # 不要なコアを削除（逆順で削除）
  if current_cores > needed_cores:
    for i in range(current_cores - 1, needed_cores - 1, -1):
      if i < _pattern_cores.size():
        attack_core_slot.remove_core(_pattern_cores[i])
        _pattern_cores.remove_at(i)

  # 必要なコアを追加
  elif current_cores < needed_cores:
    for i in range(current_cores, needed_cores):
      var new_core = attack_core_slot.add_core(core_scene)
      _pattern_cores.append(new_core)

  # 各コアに独立したパターンを割り当て
  for i in range(patterns.size()):
    _pattern_cores[i].attack_pattern = patterns[i]
    _pattern_cores[i].cooldown_sec = patterns[i].burst_delay


func clear_all_pattern_cores():
  """全てのパターンコアを削除"""
  for core in _pattern_cores:
    if is_instance_valid(core):
      attack_core_slot.remove_core(core)

  _pattern_cores.clear()
