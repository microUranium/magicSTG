extends Area2D
class_name EnemyBase

const DamageNumberScene = preload("res://scripts/ui/DamageNumber.gd")

signal received_damage(amount: int, isInvincible: bool)
signal destroyed

@export
var destroy_particles_scene: PackedScene = preload("res://scenes/enemy/destroy_particle.tscn")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slot := $AttackCoreSlot
@export var drop_table: Array[DropTableEntry] = []
@export var skip_boss_defeat_effect: bool = false  # ボス撃破エフェクトをスキップするかどうか
@export var isInvincible: bool = false  # 無敵状態かどうか
@export var show_damage_numbers: bool = true  # 被弾ダメージ数字を表示するか（デバッグビルドのみ有効）
## 撃破時に一度だけ全コアを撃つスロット（撃破時の攻撃）。空なら何もしない。
## 通常攻撃のスロットとは別に置き、パターンの auto_start は false にする
@export var death_attack_slot: UniversalAttackCoreSlot = null

var _damage_flash_time: float
var _is_hit_per_frame: bool = false  # フレームごとの被弾フラグ
var _is_dead: bool = false  # 撃破処理の二重実行防止フラグ


func _ready():
  add_to_group("enemies")
  $HpNode.connect("hp_changed", Callable(self, "on_hp_changed"))
  animated_sprite.play("default")


func take_damage(amount: int) -> void:
  emit_signal("received_damage", amount, isInvincible)
  # デバッグ用ダメージ表示（デバッグビルド時のみ）
  if show_damage_numbers and OS.is_debug_build():
    DamageNumberScene.spawn(global_position, amount, isInvincible)
  if isInvincible:  # 無敵状態ならダメージを受けない
    return
  $HpNode.take_damage(amount)
  _is_hit_per_frame = true
  flash_white()


## 一度に大きなダメージ（道連など）を与える。HP は get_burst_hp_floor() より下には減らさない。
## HP でフェーズが切り替わるボスで、フェーズを一度に複数飛ばさないためのもの。
## 下限で止まって与えるダメージが 0 になったときは、何もしない。
func take_burst_damage(amount: int) -> void:
  var hp_node = get_node_or_null("HpNode")
  if hp_node == null:
    return
  var clamped := mini(amount, maxi(0, int(hp_node.current_hp) - get_burst_hp_floor()))
  if clamped > 0:
    take_damage(clamped)


## take_burst_damage() で HP をどこまで減らしてよいか。既定は 0（倒してよい）。
## HP でフェーズが切り替わるボスは、次のフェーズに切り替わる HP のうち最も高い値を返す
## （境目ちょうどで止まるので、次のフェーズには必ず進み、その先へは飛ばない）。
func get_burst_hp_floor() -> int:
  return 0


## HP の割合 ratio で切り替わる境目の HP（current_hp <= max_hp * ratio を満たす最大の整数）
func hp_threshold(ratio: float) -> int:
  var hp_node = get_node_or_null("HpNode")
  if hp_node == null:
    return 0
  return floori(hp_node.max_hp * ratio)


## HP でフェーズが切り替わるボス向けの get_burst_hp_floor() の共通処理。
## phase_end_ratios = {フェーズ番号: そのフェーズを終える HP の割合}。
## 今のフェーズ以降で最初に来る境目を下限にする（境目のないフェーズ＝会話などを挟んでも、
## その先の境目を飛ばさない）。この先に境目がなければ 0（倒してよい）。
func phase_burst_hp_floor(phase_idx: int, phase_end_ratios: Dictionary) -> int:
  var next_idx := -1
  for idx in phase_end_ratios:
    if idx >= phase_idx and (next_idx < 0 or idx < next_idx):
      next_idx = idx
  if next_idx < 0:
    return 0
  return hp_threshold(phase_end_ratios[next_idx])


## 撃破処理の多重実行を防ぐガード。撃破処理へ初めて到達したときのみ true を返す。
## 同一フレームで複数の弾が被弾すると on_hp_changed が複数回 current_hp<=0 で呼ばれ、
## SFX・ドロップ・弾消去などが二重に走るため、各撃破ブランチの先頭で呼び出すこと。
func mark_dead_once() -> bool:
  if _is_dead:
    return false
  _is_dead = true
  return true


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if current_hp <= 0:
    if not mark_dead_once():  # 同一フレームでの多重被弾による撃破処理の重複を防ぐ
      return
    emit_signal("destroyed")
    StageSignals.emit_enemy_defeated(self)  # 強奪の加護など、敵撃破を購読する側へ通知
    _fire_death_attack()
    _spawn_destroy_particles()
    _drop_item()
    StageSignals.emit_signal("sfx_play_requested", "destroy_enemy", global_position, 0, 0)
    queue_free()


func _fire_death_attack() -> void:
  """撃破時の攻撃。death_attack_slot の全コアを一度だけ撃つ。
  弾は撃った瞬間に弾の親（敵の外）へ生成されるので、この後に敵が消えても残る"""
  if is_instance_valid(death_attack_slot):
    death_attack_slot.trigger_all_cores()


func _spawn_destroy_particles():
  if destroy_particles_scene:
    var p: CPUParticles2D = destroy_particles_scene.instantiate()
    get_tree().current_scene.add_child(p)
    p.global_position = global_position
    p.restart()


func _drop_item() -> void:
  if drop_table.size() > 0:
    LootSystem.spawn_drop(global_position, drop_table)


func set_parameter(_name: String, _value: String) -> void:
  # 継承先で実装されることを期待
  pass


func _process(delta: float) -> void:
  _update_flashing(delta)

  if _is_hit_per_frame:
    _is_hit_per_frame = false
    StageSignals.emit_signal("sfx_play_requested", "hit_enemy", global_position, -10, 0)


func _update_flashing(delta):
  if !animated_sprite:
    return

  if _damage_flash_time > 0.0:
    _damage_flash_time -= delta
    animated_sprite.modulate = Color(1.0, 0.35, 0.35, animated_sprite.modulate.a)

  if _damage_flash_time <= 0.0:
    animated_sprite.modulate = Color(1.0, 1.0, 1.0, animated_sprite.modulate.a)
    _damage_flash_time = 0.0


func flash_white(duration := 0.1):
  print_debug("EnemyBase: Flashing white for ", duration, " seconds")
  _damage_flash_time = duration
