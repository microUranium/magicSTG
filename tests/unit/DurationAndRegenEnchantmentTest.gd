# === エンチャント「持続」「応急」「危癒」機能テスト ===
# テスト対象:
#   持続 (blessing_duration_pct)
#     1. ティア値と付与先（迷彩）、迷彩の効果時間への反映
#   応急 (regen_on_hit_chance_pct)
#     2. ティア値と付与先（回復）
#     3. 確率 1.0：実ダメージを受けると、HP減少の反映後に heal_amount 回復する
#     4. damage=0（シールドが受け止めた等）では回復しない
#     5. 被弾でHPが0になったら回復しない
#     6. 未付与なら回復しない
#   危癒 (regen_low_hp_interval_pct)
#     7. ティア値と付与先（回復）
#     8. 体力の減り具合に応じて回復間隔が短くなる（残HP3割以下で最大）
#     9. 待機の途中で間隔が変わったら、進んだ割合を保って残り時間を計算し直す
#    10. 未付与なら体力が変わっても間隔は変わらない
extends GdUnitTestSuite

const CamouflageBlessing := preload("res://scripts/player/CamouflageBlessing.gd")
const RegenBlessing := preload("res://scripts/player/RegenBlessing.gd")

const DURATION_PATH := "res://resources/data/enchantment_blessing_duration_pct.tres"
const ON_HIT_PATH := "res://resources/data/enchantment_regen_on_hit_chance_pct.tres"
const LOW_HP_PATH := "res://resources/data/enchantment_regen_low_hp_interval_pct.tres"


class MockHpNode:
  extends Node
  signal hp_changed(current_hp: int, max_hp: int)

  var max_hp := 10
  var current_hp := 10

  func take_damage(amount: int = 1) -> void:
    current_hp = maxi(0, current_hp - amount)
    hp_changed.emit(current_hp, max_hp)

  func heal(amount: int = 1) -> void:
    current_hp = mini(max_hp, current_hp + amount)
    hp_changed.emit(current_hp, max_hp)


class MockPlayer:
  extends Node2D
  signal damage_received(damage)
  signal healing_received(amount)

  var hp_node := MockHpNode.new()

  func _ready() -> void:
    add_child(hp_node)
    healing_received.connect(hp_node.heal)

  ## Player.take_damage() と同じ順序：damage_received を発火してから HP を減らす
  func take_damage(final_damage: int) -> void:
    damage_received.emit(final_damage)
    if final_damage > 0:
      hp_node.take_damage(final_damage)


## 単一キー・単一ティア（Lv1）のテスト用エンチャント
func _make_enchant(key: String, value: float) -> Enchantment:
  var tier := EnchantmentTier.new()
  tier.level = 1
  tier.modifiers = {key: value}
  var enc := Enchantment.new()
  enc.id = StringName(key)
  enc.tiers = [tier]
  return enc


func _make_inst(base_modifiers: Dictionary, enchants: Dictionary = {}) -> ItemInstance:
  var proto := BlessingItem.new()
  proto.id = "test_blessing"
  proto.display_name = "テスト加護"
  proto.base_modifiers = base_modifiers
  var inst := ItemInstance.new(proto)
  for enc in enchants:
    inst.enchantments[enc] = enchants[enc]
  return inst


func _make_player() -> MockPlayer:
  var player: MockPlayer = auto_free(MockPlayer.new())
  add_child(player)
  return player


func _equip_regen(player: MockPlayer, enchants: Dictionary, interval := 5.0) -> Node:
  var blessing: Node = auto_free(RegenBlessing.new())
  add_child(blessing)  # _ready で HealTimer を作るため先にツリーへ入れる
  blessing.item_inst = _make_inst({"regen_amount": 1, "regen_interval_sec": interval}, enchants)
  blessing.on_equip(player)
  blessing._connect_signals()  # player は既に ready 済みのため手動で接続
  return blessing


func _assert_tiers(path: String, key: String, expected: Dictionary) -> void:
  var enchant: Enchantment = load(path)
  assert_str(str(enchant.id)).is_equal(key)
  for level in expected:
    var value := float(enchant.get_modifiers(level)[key])
    assert_float(value).is_equal_approx(expected[level], 0.0001)


func _assert_allowed_only(path: String, allowed_item_ids: Array) -> void:
  var enchant: Enchantment = load(path)
  for item_id in [
    "blessing_camouflage",
    "blessing_fortitude",
    "blessing_hp_boost",
    "blessing_laststand",
    "blessing_nullify",
    "blessing_proximity",
    "blessing_regen",
    "blessing_shield",
  ]:
    var item: ItemBase = load("res://resources/data/%s.tres" % item_id)
    var allowed := item.allows_enchantment(enchant)
    assert_bool(allowed).override_failure_message(item_id).is_equal(item_id in allowed_item_ids)


# --- 持続 ------------------------------------------------------------


func test_duration_enchantment_data() -> void:
  var enchant: Enchantment = load(DURATION_PATH)
  assert_str(enchant.display_name).is_equal("持続")
  assert_str(enchant.description).is_equal("加護の効果時間が伸びます。")
  _assert_tiers(DURATION_PATH, "blessing_duration_pct", {1: 0.2, 2: 0.5, 3: 1.0})
  _assert_allowed_only(DURATION_PATH, ["blessing_camouflage"])


func test_duration_extends_camouflage() -> void:
  var expected := {1: 12.0, 2: 15.0, 3: 20.0}
  for level in expected:
    var blessing: Node = auto_free(CamouflageBlessing.new())
    blessing.item_inst = _make_inst(
      {"camouflage_duration_sec": 10.0, "max_uses": 2}, {load(DURATION_PATH): level}
    )
    assert_float(blessing.duration_sec).is_equal_approx(expected[level], 0.001)


# --- 応急 ------------------------------------------------------------


func test_on_hit_enchantment_data() -> void:
  var enchant: Enchantment = load(ON_HIT_PATH)
  assert_str(enchant.display_name).is_equal("応急")
  assert_str(enchant.description).is_equal("ダメージを受けた時、一定確率で即時回復します。")
  _assert_tiers(ON_HIT_PATH, "regen_on_hit_chance_pct", {1: 0.05, 2: 0.2, 3: 0.5})
  _assert_allowed_only(ON_HIT_PATH, ["blessing_regen"])


func test_on_hit_heals_after_damage_is_applied() -> void:
  var player := _make_player()
  var blessing := _equip_regen(player, {_make_enchant("regen_on_hit_chance_pct", 1.0): 1})
  var healed := [0]
  blessing.on_hit_healed.connect(func(amount): healed[0] += amount)

  player.take_damage(3)  # 10 → 7
  assert_int(player.hp_node.current_hp).is_equal(7)  # 回復はまだ（被弾の反映後に行う）
  await await_idle_frame()

  assert_int(player.hp_node.current_hp).is_equal(8)
  assert_int(healed[0]).is_equal(1)


func test_on_hit_ignores_zero_damage() -> void:
  var player := _make_player()
  player.hp_node.current_hp = 5
  var blessing := _equip_regen(player, {_make_enchant("regen_on_hit_chance_pct", 1.0): 1})
  var healed := [0]
  blessing.on_hit_healed.connect(func(amount): healed[0] += amount)

  player.take_damage(0)
  await await_idle_frame()

  assert_int(player.hp_node.current_hp).is_equal(5)
  assert_int(healed[0]).is_equal(0)


func test_on_hit_does_not_heal_after_defeat() -> void:
  var player := _make_player()
  player.hp_node.current_hp = 3
  var blessing := _equip_regen(player, {_make_enchant("regen_on_hit_chance_pct", 1.0): 1})
  var healed := [0]
  blessing.on_hit_healed.connect(func(amount): healed[0] += amount)

  player.take_damage(3)  # 3 → 0（致命傷）
  await await_idle_frame()

  assert_int(player.hp_node.current_hp).is_equal(0)
  assert_int(healed[0]).is_equal(0)


func test_without_on_hit_no_instant_heal() -> void:
  var player := _make_player()
  var blessing := _equip_regen(player, {})
  var healed := [0]
  blessing.on_hit_healed.connect(func(amount): healed[0] += amount)

  player.take_damage(3)
  await await_idle_frame()

  assert_int(player.hp_node.current_hp).is_equal(7)
  assert_int(healed[0]).is_equal(0)


# --- 危癒 ------------------------------------------------------------


func test_low_hp_enchantment_data() -> void:
  var enchant: Enchantment = load(LOW_HP_PATH)
  assert_str(enchant.display_name).is_equal("危癒")
  assert_str(enchant.description).is_equal("体力が少ないほど回復の間隔が短くなります。")
  _assert_tiers(LOW_HP_PATH, "regen_low_hp_interval_pct", {1: 0.15, 2: 0.3, 3: 0.5})
  _assert_allowed_only(LOW_HP_PATH, ["blessing_regen"])


func test_low_hp_shortens_interval_by_hp() -> void:
  var player := _make_player()
  var blessing := _equip_regen(player, {load(LOW_HP_PATH): 3}, 5.0)  # 最大 -50%
  assert_float(blessing.heal_interval).is_equal_approx(5.0, 0.001)

  player.hp_node.max_hp = 100
  var cases := [
    [100, 5.0],  # 満タン：短縮なし
    [65, 3.75],  # 減り具合 0.5
    [30, 2.5],  # 3割：最大
    [10, 2.5],  # 3割未満も最大のまま
  ]
  for c in cases:
    player.hp_node.current_hp = c[0]
    player.hp_node.hp_changed.emit(c[0], 100)
    var label := "hp=%d" % c[0]
    assert_float(blessing.heal_interval).override_failure_message(label).is_equal_approx(
      c[1], 0.001
    )


func test_low_hp_keeps_progress_when_interval_changes() -> void:
  var player := _make_player()
  var blessing := _equip_regen(player, {load(LOW_HP_PATH): 3}, 5.0)
  # 間隔 5 秒のうち 60% 進んだ状態（残り 2 秒）を作る
  blessing.heal_timer.start(2.0)

  player.hp_node.hp_changed.emit(3, 10)  # 3割 → 間隔 2.5 秒

  assert_float(blessing.heal_interval).is_equal_approx(2.5, 0.001)
  # 残り 40% × 2.5 秒 = 1.0 秒
  assert_float(blessing.heal_timer.time_left).is_equal_approx(1.0, 0.02)


func test_without_low_hp_interval_is_fixed() -> void:
  var player := _make_player()
  var blessing := _equip_regen(player, {}, 5.0)

  player.hp_node.hp_changed.emit(1, 10)

  assert_float(blessing.heal_interval).is_equal_approx(5.0, 0.001)
