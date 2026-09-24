# === 不屈の加護 機能テスト ===
# テスト対象:
#   1. base_modifiers / エンチャント「保持」からのパラメータ算出
#   2. 致命ダメージでのみ発動し、HPが規定割合まで回復すること
#   3. 使用回数を使い切ったら発動しないこと
#   4. BlessingContainer が「全加護を通した後の残ダメージ」で判定すること
#      （防壁が吸収できるダメージでは回数を消費しない）
#   5. 復活後は一定時間無敵で、その間は被弾しないこと
#   6. 復活演出（効果音・画面揺れ・収束パーティクル）が出ること
class_name FortitudeBlessingTest
extends GdUnitTestSuite

const FortitudeBlessing := preload("res://scripts/player/FortitudeBlessing.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"


class MockHpNode:
  extends Node
  signal hp_changed(current_hp: int, max_hp: int)

  var max_hp := 20
  var current_hp := 20

  func take_damage(amount: int = 1) -> void:
    current_hp = maxi(0, current_hp - amount)
    hp_changed.emit(current_hp, max_hp)

  func heal(amount: int = 1) -> void:
    current_hp = mini(max_hp, current_hp + amount)
    hp_changed.emit(current_hp, max_hp)


class MockPlayer:
  extends Node2D

  var hp_node := MockHpNode.new()
  var invincible_sec := 0.0

  func _ready() -> void:
    add_child(hp_node)

  func set_invincible(duration_sec: float) -> void:
    invincible_sec = duration_sec


## process_damage で必ず一定量を肩代わりする、順序確認用のダミー加護
class AbsorbBlessing:
  extends BlessingBase

  var absorb := 0

  func process_damage(_player, damage):
    var absorbed: int = mini(absorb, damage)
    absorb -= absorbed
    return damage - absorbed


var _blessing: BlessingBase
var _player: MockPlayer


func before_test() -> void:
  _player = auto_free(MockPlayer.new())
  add_child(_player)

  _blessing = auto_free(FortitudeBlessing.new())
  add_child(_blessing)
  _blessing.item_inst = ItemInstance.new(_make_proto())
  _blessing.on_equip(_player)


func _make_proto(uses := 1, ratio := 0.5, invincible := 2.0) -> BlessingItem:
  var proto := BlessingItem.new()
  proto.id = "blessing_fortitude"
  proto.display_name = "不屈の加護"
  proto.base_modifiers = {
    "max_uses": uses,
    "fortitude_revive_hp_ratio": ratio,
    "fortitude_invincible_sec": invincible,
  }
  return proto


## ツリーに入れない（_ready のセーブデータ読み込みを走らせない）容器を作る
func _make_container(list: Array) -> BlessingContainer:
  var container: BlessingContainer = auto_free(BlessingContainer.new())
  var typed: Array[BlessingBase] = []
  for b in list:
    typed.append(b)
  container.blessings = typed
  return container


func test_stats_from_base_modifiers() -> void:
  assert_int(_blessing.max_uses).is_equal(1)
  assert_int(_blessing.get_uses_remaining()).is_equal(1)
  assert_float(_blessing.revive_hp_ratio).is_equal_approx(0.5, 0.001)
  assert_float(_blessing.invincible_sec).is_equal_approx(2.0, 0.001)


func test_uses_increase_with_retention_enchantment() -> void:
  var enchant := load("res://resources/data/enchantment_blessing_uses_add.tres") as Enchantment
  var inst := ItemInstance.new(_make_proto())
  inst.enchantments[enchant] = 2  # 「保持」Lv2 = +2

  var blessing: Node = auto_free(FortitudeBlessing.new())
  add_child(blessing)
  blessing.item_inst = inst
  blessing.on_equip(_player)

  assert_int(blessing.max_uses).is_equal(3)
  assert_int(blessing.get_uses_remaining()).is_equal(3)


func test_revive_restores_hp_ratio_and_invincibility() -> void:
  _player.hp_node.current_hp = 5

  assert_bool(_blessing.process_fatal_damage(_player, 5)).is_true()

  assert_int(_player.hp_node.current_hp).is_equal(10)  # 最大HP20の50%
  assert_float(_player.invincible_sec).is_equal_approx(2.0, 0.001)
  assert_int(_blessing.get_uses_remaining()).is_equal(0)


func test_no_revive_when_uses_exhausted() -> void:
  _player.hp_node.current_hp = 5
  assert_bool(_blessing.process_fatal_damage(_player, 5)).is_true()

  _player.hp_node.current_hp = 3
  assert_bool(_blessing.process_fatal_damage(_player, 3)).is_false()
  assert_int(_player.hp_node.current_hp).is_equal(3)  # 回復しない


func test_container_triggers_only_on_remaining_fatal_damage() -> void:
  var absorber: BlessingBase = auto_free(AbsorbBlessing.new())
  absorber.absorb = 100
  var container := _make_container([absorber, _blessing])
  _player.hp_node.current_hp = 5

  # 防壁役が全部吸収 → 不屈は発動しない
  assert_int(container.process_damage(_player, 50)).is_equal(0)
  assert_int(_blessing.get_uses_remaining()).is_equal(1)

  # 吸収しきれない致命ダメージ → 不屈が発動してダメージ0
  absorber.absorb = 1
  assert_int(container.process_damage(_player, 50)).is_equal(0)
  assert_int(_blessing.get_uses_remaining()).is_equal(0)
  assert_int(_player.hp_node.current_hp).is_equal(10)


func test_non_fatal_damage_passes_through() -> void:
  var container := _make_container([_blessing])
  _player.hp_node.current_hp = 20

  assert_int(container.process_damage(_player, 5)).is_equal(5)
  assert_int(_blessing.get_uses_remaining()).is_equal(1)


func test_revive_plays_effects() -> void:
  var sfx_monitor := monitor_signals(StageSignals, false)
  _player.hp_node.current_hp = 5

  _blessing.process_fatal_damage(_player, 5)

  # 画面揺れ（撃破時と同じ request_start_vibration）
  await assert_signal(sfx_monitor).wait_until(50).is_emitted("request_start_vibration")
  await (assert_signal(sfx_monitor).wait_until(50).is_emitted(
    "sfx_play_requested", ["fortitude", _player.global_position, 0.0, 1.0]
  ))


func test_revive_particles_converge_inward() -> void:
  # 収束パーティクル：外周から出て中心向きに加速する（撃破時の飛散と逆）
  var particles: CPUParticles2D = auto_free(
    load("res://scenes/player/revive_particle_player.tscn").instantiate()
  )

  assert_int(particles.emission_shape).is_equal(CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE)
  assert_float(particles.emission_sphere_radius).is_greater(0.0)
  assert_float(particles.radial_accel_max).is_less(0.0)  # 負 = 中心方向
  assert_float(particles.initial_velocity_max).is_equal_approx(0.0, 0.001)
  assert_bool(particles.one_shot).is_true()


func test_player_ignores_damage_while_invincible() -> void:
  var player: Node2D = auto_free(load(PLAYER_SCENE).instantiate())
  add_child(player)
  await await_idle_frame()
  var hp_before: int = player.hp_node.current_hp

  player.set_invincible(0.5)
  player.take_damage(3)

  assert_bool(player.is_invincible()).is_true()
  assert_int(player.hp_node.current_hp).is_equal(hp_before)
