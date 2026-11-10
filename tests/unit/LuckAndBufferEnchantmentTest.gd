# === エンチャント「幸運」「緩衝」機能テスト ===
# テスト対象:
#   幸運 (blessing_free_use_chance_pct)
#     1. ティア値と付与先（不屈・打消・迷彩）
#     2. 確率 1.0 ならアクティブ加護（打消）を発動しても使用回数が減らない
#        （クールダウンには入り、free_use_triggered が出る）
#     3. 未付与なら従来どおり使用回数が減る
#     4. 残り0回のときは幸運があっても発動できない
#     5. 不屈も確率 1.0 なら復活で回数が減らず、使い切り表示にならない
#   緩衝 (shield_damage_taken_pct)
#     6. ティア値と付与先（障壁）
#     7. 端数を小数部分の確率で切り上げる計算（roll を固定して決定的に検証）
#     8. ダメージ0になったときはシールドが減らず、自然回復の待機はリセットされる
#     9. シールド破壊中は元のダメージがそのまま通る
extends GdUnitTestSuite

const NullifyBlessing := preload("res://scripts/player/NullifyBlessing.gd")
const FortitudeBlessing := preload("res://scripts/player/FortitudeBlessing.gd")
const DefensiveBlessing := preload("res://scripts/player/DefensiveBlessing.gd")
const PlayerStubScript := preload("res://tests/stubs/PlayerStub.gd")

const LUCK_PATH := "res://resources/data/enchantment_blessing_free_use_chance_pct.tres"
const BUFFER_PATH := "res://resources/data/enchantment_shield_damage_taken_pct.tres"


class MockHpNode:
  extends Node
  var max_hp := 20
  var current_hp := 20

  func take_damage(amount: int = 1) -> void:
    current_hp = maxi(0, current_hp - amount)

  func heal(amount: int = 1) -> void:
    current_hp = mini(max_hp, current_hp + amount)


class MockPlayer:
  extends Node2D
  var hp_node := MockHpNode.new()

  func _ready() -> void:
    add_child(hp_node)

  func set_invincible(_duration_sec: float) -> void:
    pass


## 単一キー・単一ティア（Lv1）のテスト用エンチャント
func _make_enchant(key: String, value: float) -> Enchantment:
  var tier := EnchantmentTier.new()
  tier.level = 1
  tier.modifiers = {key: value}
  var enc := Enchantment.new()
  enc.id = StringName(key)
  enc.tiers = [tier]
  return enc


func _make_inst(base_modifiers: Dictionary, enchant: Enchantment = null) -> ItemInstance:
  var proto := BlessingItem.new()
  proto.id = "test_blessing"
  proto.display_name = "テスト加護"
  proto.base_modifiers = base_modifiers
  var inst := ItemInstance.new(proto)
  if enchant:
    inst.enchantments[enchant] = 1
  return inst


func _equip(script: Script, inst: ItemInstance, player: Node) -> Node:
  var blessing: Node = auto_free(script.new())
  add_child(blessing)  # _ready でタイマーを作るため先にツリーへ入れる
  blessing.item_inst = inst
  blessing.on_equip(player)
  return blessing


func _make_player() -> Node2D:
  var player: Node2D = auto_free(MockPlayer.new())
  add_child(player)
  return player


# --- 幸運 ------------------------------------------------------------


func test_luck_enchantment_data() -> void:
  var enchant: Enchantment = load(LUCK_PATH)

  assert_str(str(enchant.id)).is_equal("blessing_free_use_chance_pct")
  assert_str(enchant.display_name).is_equal("幸運")
  assert_str(enchant.description).is_equal("一定確率で使用回数を消費せずに加護を発動します。")
  var expected := {1: 0.1, 2: 0.3, 3: 0.7}
  for level in expected:
    var chance := float(enchant.get_modifiers(level)["blessing_free_use_chance_pct"])
    assert_float(chance).is_equal_approx(expected[level], 0.0001)

  for item_id in ["blessing_fortitude", "blessing_nullify", "blessing_camouflage"]:
    var item: ItemBase = load("res://resources/data/%s.tres" % item_id)
    assert_bool(item.allows_enchantment(enchant)).override_failure_message(item_id).is_true()
  var shield: ItemBase = load("res://resources/data/blessing_shield.tres")
  assert_bool(shield.allows_enchantment(enchant)).is_false()


func test_luck_keeps_active_blessing_uses() -> void:
  var inst := _make_inst(
    {"max_uses": 2, "blessing_cooldown_sec": 1.0},
    _make_enchant("blessing_free_use_chance_pct", 1.0)
  )
  var blessing = _equip(NullifyBlessing, inst, _make_player())
  var triggered := [0]
  blessing.free_use_triggered.connect(func(): triggered[0] += 1)

  assert_bool(blessing.activate()).is_true()

  assert_int(blessing.get_uses_remaining()).is_equal(2)
  assert_int(triggered[0]).is_equal(1)
  assert_bool(blessing.can_activate()).is_false()  # クールダウンには入る


func test_without_luck_active_blessing_consumes_use() -> void:
  var inst := _make_inst({"max_uses": 2, "blessing_cooldown_sec": 1.0})
  var blessing = _equip(NullifyBlessing, inst, _make_player())
  var triggered := [0]
  blessing.free_use_triggered.connect(func(): triggered[0] += 1)

  assert_bool(blessing.activate()).is_true()

  assert_int(blessing.get_uses_remaining()).is_equal(1)
  assert_int(triggered[0]).is_equal(0)


func test_luck_cannot_activate_with_zero_uses() -> void:
  var inst := _make_inst(
    {"max_uses": 0, "blessing_cooldown_sec": 1.0},
    _make_enchant("blessing_free_use_chance_pct", 1.0)
  )
  var blessing = _equip(NullifyBlessing, inst, _make_player())

  assert_bool(blessing.activate()).is_false()
  assert_int(blessing.get_uses_remaining()).is_equal(0)


func test_luck_keeps_fortitude_uses() -> void:
  var player := _make_player()
  var inst := _make_inst(
    {"max_uses": 1, "fortitude_revive_hp_ratio": 0.5, "fortitude_invincible_sec": 2.0},
    _make_enchant("blessing_free_use_chance_pct", 1.0)
  )
  var blessing = _equip(FortitudeBlessing, inst, player)
  player.hp_node.current_hp = 5

  assert_bool(blessing.process_fatal_damage(player, 5)).is_true()

  assert_int(blessing.get_uses_remaining()).is_equal(1)
  assert_str(blessing.gauge_style).is_equal("durability")  # 使い切り表示にならない
  # 回数が残っているので、もう一度復活できる
  player.hp_node.current_hp = 3
  assert_bool(blessing.process_fatal_damage(player, 3)).is_true()


# --- 緩衝 ------------------------------------------------------------


func test_buffer_enchantment_data() -> void:
  var enchant: Enchantment = load(BUFFER_PATH)

  assert_str(str(enchant.id)).is_equal("shield_damage_taken_pct")
  assert_str(enchant.display_name).is_equal("緩衝")
  assert_str(enchant.description).is_equal("シールドが受けるダメージ量を減らします。")
  var expected := {1: -0.1, 2: -0.2, 3: -0.5}
  for level in expected:
    var pct := float(enchant.get_modifiers(level)["shield_damage_taken_pct"])
    assert_float(pct).is_equal_approx(expected[level], 0.0001)

  var shield: ItemBase = load("res://resources/data/blessing_shield.tres")
  assert_bool(shield.allows_enchantment(enchant)).is_true()


func test_reduce_shield_damage_rounds_fraction_by_probability() -> void:
  # [damage, pct, roll, expected]
  var cases := [
    [1, -0.5, 0.49, 1],  # 0.5 → roll < 0.5 で切り上げ
    [1, -0.5, 0.5, 0],
    [1, -0.1, 0.89, 1],  # 0.9
    [1, -0.1, 0.9, 0],
    [2, -0.1, 0.79, 2],  # 1.8
    [2, -0.1, 0.8, 1],
    [2, -0.5, 0.0, 1],  # 1.0 ちょうど（端数なし）
    [2, -0.5, 0.99, 1],
    [3, -0.5, 0.49, 2],  # 1.5
    [3, -0.5, 0.5, 1],
    [5, -0.1, 0.0, 5],  # 4.5
    [5, -0.1, 0.99, 4],
    [5, -0.2, 0.0, 4],  # 4.0 ちょうど（浮動小数誤差で 5 にならない）
    [10, -0.1, 0.0, 9],
    [10, -0.2, 0.0, 8],
    [10, -0.5, 0.0, 5],
    [10, -0.5, 0.99, 5],
  ]
  for c in cases:
    var actual := DefensiveBlessing.reduce_shield_damage(c[0], c[1], c[2])
    var label := "damage=%d pct=%s roll=%s" % [c[0], c[1], c[2]]
    assert_int(actual).override_failure_message(label).is_equal(c[3])


func test_reduce_shield_damage_without_enchant_is_identity() -> void:
  for roll in [0.0, 0.5, 0.99]:
    assert_int(DefensiveBlessing.reduce_shield_damage(3, 0.0, roll)).is_equal(3)
  assert_int(DefensiveBlessing.reduce_shield_damage(0, -0.5, 0.0)).is_equal(0)


func _equip_shield(enchant: Enchantment) -> Node:
  var player: Node2D = auto_free(PlayerStubScript.new())
  add_child(player)
  var inst := _make_inst({"shield_hp": 50, "shield_recover_delay": 0.2}, enchant)
  return _equip(DefensiveBlessing, inst, player)


func test_shield_applies_buffer_level3() -> void:
  var inst_enchant: Enchantment = load(BUFFER_PATH)
  var player: Node2D = auto_free(PlayerStubScript.new())
  add_child(player)
  var inst := _make_inst({"shield_hp": 50, "shield_recover_delay": 0.2})
  inst.enchantments[inst_enchant] = 3  # -50%
  var shield = _equip(DefensiveBlessing, inst, player)

  assert_int(shield.process_damage(player, 10)).is_equal(0)
  assert_int(shield.shield_current).is_equal(45)  # 10 → 5（端数なしなので乱数に依存しない）


func test_shield_zero_damage_keeps_shield_but_resets_regen_wait() -> void:
  # -100% なら必ず 0 ダメージになる
  var shield = _equip_shield(_make_enchant("shield_damage_taken_pct", -1.0))
  shield._time_since_damage = 3.0

  assert_int(shield.process_damage(shield.player_ref, 5)).is_equal(0)

  assert_int(shield.shield_current).is_equal(50)
  assert_bool(shield.is_broken).is_false()
  assert_float(shield._time_since_damage).is_equal_approx(0.0, 0.0001)


func test_broken_shield_passes_original_damage() -> void:
  var shield = _equip_shield(_make_enchant("shield_damage_taken_pct", -0.5))
  shield.process_damage(shield.player_ref, 100)  # 50 → 破壊
  assert_bool(shield.is_broken).is_true()

  assert_int(shield.process_damage(shield.player_ref, 3)).is_equal(3)
