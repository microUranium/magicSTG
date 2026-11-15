# === エンチャント「庇護」(hp_extra_pct) 機能テスト ===
# テスト対象:
#   HpNode
#     1. 被弾時は追加の体力から先に減り、足りない分だけ通常の体力が減る
#     2. 回復しても追加の体力は増えない
#     3. 追加の体力だけが減ったときも hp_changed / extra_hp_changed が出る
#   体力増強の加護
#     4. 最大体力（加護・増健の反映後）の割合だけ追加の体力を得る
#     5. 加護を外すと追加の体力は 0 になる
#     6. ティア値と付与先（体力増強のみ）
#   BlessingContainer（致命傷の判定）
#     7. 追加の体力が残っている間は致命傷にならず、不屈は発動しない
#     8. 追加の体力を超えて通常の体力も尽きる被弾は致命傷になり、不屈で復活しても追加の体力は戻らない
#        （復活時の体力が、追加の体力に吸われず最大体力の割合ちょうどになる）
#   HPBar
#     9. 追加の体力のバーは「残り ÷ 付与時の量」で表示し、0 で非表示
#    10. hud.tscn の ExtraBar が専用画像を使っている
extends GdUnitTestSuite

const HpNodeScript := preload("res://scripts/player/HpNode.gd")
const HpBoostBlessing := preload("res://scripts/player/HpBoostBlessing.gd")
const FortitudeBlessing := preload("res://scripts/player/FortitudeBlessing.gd")
const HPBarScript := preload("res://scripts/ui/HPBar.gd")

const ENCHANT_PATH := "res://resources/data/enchantment_hp_extra_pct.tres"
const HP_ADD_PATH := "res://resources/data/enchantment_hp_add.tres"
const EXTRA_TEXTURE_PATH := "res://assets/gfx/sprites/HPBar_progress_extra.png"


class MockPlayer:
  extends Node2D
  var hp_node: Node
  var invincible_sec := 0.0

  func _init(hp_script: Script, max_hp: int) -> void:
    hp_node = hp_script.new()
    hp_node.max_hp = max_hp

  func _ready() -> void:
    add_child(hp_node)

  func set_invincible(duration_sec: float) -> void:
    invincible_sec = duration_sec


func _make_player(max_hp := 10) -> MockPlayer:
  var player: MockPlayer = auto_free(MockPlayer.new(HpNodeScript, max_hp))
  add_child(player)
  return player


func _make_inst(base_modifiers: Dictionary, enchants: Dictionary = {}) -> ItemInstance:
  var proto := BlessingItem.new()
  proto.id = "test_blessing"
  proto.display_name = "テスト加護"
  proto.base_modifiers = base_modifiers
  var inst := ItemInstance.new(proto)
  for enc in enchants:
    inst.enchantments[enc] = enchants[enc]
  return inst


func _equip(script: Script, inst: ItemInstance, player: Node) -> Node:
  var blessing: Node = auto_free(script.new())
  add_child(blessing)
  blessing.item_inst = inst
  blessing.on_equip(player)
  return blessing


# --- HpNode ----------------------------------------------------------


func test_damage_consumes_extra_hp_first() -> void:
  var hp := _make_player().hp_node
  hp.set_extra_hp(2)

  hp.take_damage(5)

  assert_int(hp.extra_hp).is_equal(0)
  assert_int(hp.current_hp).is_equal(7)
  assert_int(hp.extra_hp_max).is_equal(2)  # 表示基準は付与時の量のまま


func test_damage_within_extra_hp_keeps_current_hp() -> void:
  var hp := _make_player().hp_node
  hp.set_extra_hp(5)
  var hp_events := [0]
  var extra_events := []
  hp.hp_changed.connect(func(_c, _m): hp_events[0] += 1)
  hp.extra_hp_changed.connect(func(e, m): extra_events.append([e, m]))

  hp.take_damage(3)

  assert_int(hp.extra_hp).is_equal(2)
  assert_int(hp.current_hp).is_equal(10)
  assert_int(hp_events[0]).is_equal(1)
  assert_array(extra_events).is_equal([[2, 5]])


func test_heal_does_not_restore_extra_hp() -> void:
  var hp := _make_player().hp_node
  hp.set_extra_hp(5)
  hp.take_damage(8)  # 追加 5 → 0、通常 10 → 7

  hp.heal(10)

  assert_int(hp.current_hp).is_equal(10)
  assert_int(hp.extra_hp).is_equal(0)


# --- 体力増強の加護 ----------------------------------------------------


func test_enchantment_data() -> void:
  var enchant: Enchantment = load(ENCHANT_PATH)
  assert_str(str(enchant.id)).is_equal("hp_extra_pct")
  assert_str(enchant.display_name).is_equal("庇護")
  var expected := {1: 0.5, 2: 1.0, 3: 2.0}
  for level in expected:
    var value := float(enchant.get_modifiers(level)["hp_extra_pct"])
    assert_float(value).is_equal_approx(expected[level], 0.0001)

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
    assert_bool(allowed).override_failure_message(item_id).is_equal(item_id == "blessing_hp_boost")


func test_grants_extra_hp_from_boosted_max_hp() -> void:
  # 素の最大体力 10 + 加護 5 = 15
  var expected := {1: 8, 2: 15, 3: 30}  # 7.5 は四捨五入で 8
  for level in expected:
    var player := _make_player(10)
    _equip(HpBoostBlessing, _make_inst({"hp_add": 5}, {load(ENCHANT_PATH): level}), player)

    assert_int(player.hp_node.max_hp).is_equal(15)
    assert_int(player.hp_node.extra_hp).override_failure_message("Lv%d" % level).is_equal(
      expected[level]
    )
    assert_int(player.hp_node.extra_hp_max).is_equal(expected[level])


func test_extra_hp_includes_hp_add_enchantment() -> void:
  # 素の最大体力 10 + 加護 5 + 増健 Lv3（+10）= 25 → Lv1（+50%）で 12.5 → 13
  var player := _make_player(10)
  var enchants := {load(ENCHANT_PATH): 1, load(HP_ADD_PATH): 3}
  _equip(HpBoostBlessing, _make_inst({"hp_add": 5}, enchants), player)

  assert_int(player.hp_node.max_hp).is_equal(25)
  assert_int(player.hp_node.extra_hp).is_equal(13)


func test_no_extra_hp_without_enchantment() -> void:
  var player := _make_player(10)
  _equip(HpBoostBlessing, _make_inst({"hp_add": 5}), player)

  assert_int(player.hp_node.extra_hp).is_equal(0)


func test_unequip_clears_extra_hp() -> void:
  var player := _make_player(10)
  var blessing := _equip(
    HpBoostBlessing, _make_inst({"hp_add": 5}, {load(ENCHANT_PATH): 2}), player
  )
  assert_int(player.hp_node.extra_hp).is_equal(15)

  blessing.on_unequip(player)

  assert_int(player.hp_node.extra_hp).is_equal(0)
  assert_int(player.hp_node.max_hp).is_equal(10)


# --- 致命傷の判定 ------------------------------------------------------


func _make_container(list: Array) -> BlessingContainer:
  var container: BlessingContainer = auto_free(BlessingContainer.new())
  var typed: Array[BlessingBase] = []
  for b in list:
    typed.append(b)
  container.blessings = typed
  return container


func test_extra_hp_prevents_fatal_and_fortitude() -> void:
  var player := _make_player(10)
  player.hp_node.set_extra_hp(5)
  var fortitude := _equip(
    FortitudeBlessing,
    _make_inst({"max_uses": 1, "fortitude_revive_hp_ratio": 0.5, "fortitude_invincible_sec": 2.0}),
    player
  )
  var container := _make_container([fortitude])

  # 合計 15 に対して 12 ダメージ：致命傷ではない
  var final_dmg := container.process_damage(player, 12)
  assert_int(final_dmg).is_equal(12)
  assert_int(fortitude.get_uses_remaining()).is_equal(1)

  player.hp_node.take_damage(final_dmg)
  assert_int(player.hp_node.extra_hp).is_equal(0)
  assert_int(player.hp_node.current_hp).is_equal(3)


func test_fatal_beyond_extra_hp_revives_without_extra() -> void:
  var player := _make_player(10)
  player.hp_node.set_extra_hp(5)
  var fortitude := _equip(
    FortitudeBlessing,
    _make_inst({"max_uses": 1, "fortitude_revive_hp_ratio": 0.5, "fortitude_invincible_sec": 2.0}),
    player
  )
  var container := _make_container([fortitude])

  # 合計 15 に対して 15 ダメージ：致命傷 → 不屈で復活
  assert_int(container.process_damage(player, 15)).is_equal(0)
  assert_int(fortitude.get_uses_remaining()).is_equal(0)
  assert_int(player.hp_node.current_hp).is_equal(5)  # 最大10の50%
  assert_int(player.hp_node.extra_hp).is_equal(0)  # 致命傷で使い切った扱い（復活でも戻らない）


# --- HPBar ------------------------------------------------------------


func _make_hp_bar() -> TextureProgressBar:
  var bar: TextureProgressBar = auto_free(HPBarScript.new())
  var extra := TextureProgressBar.new()
  extra.name = "ExtraBar"
  extra.visible = false
  bar.add_child(extra)
  add_child(bar)
  return bar


func test_hp_bar_extra_ratio_and_visibility() -> void:
  var bar := _make_hp_bar()
  var extra: TextureProgressBar = bar.get_node("ExtraBar")

  bar.update_extra(10, 10)
  assert_bool(extra.visible).is_true()
  assert_float(extra.value).is_equal_approx(95.0, 0.01)  # 満タン（表示上 95%）

  bar.update_extra(5, 10)
  assert_float(extra.value).is_equal_approx(50.0, 0.01)  # 半分（5% + 45%）

  bar.update_extra(0, 10)
  assert_bool(extra.visible).is_false()


func test_hud_extra_bar_uses_dedicated_texture() -> void:
  var hud: Node = auto_free(load("res://scenes/ui/hud.tscn").instantiate())  # ツリーには入れない
  var extra: TextureProgressBar = hud.get_node("HPBar/ExtraBar")

  assert_str(extra.texture_progress.resource_path).is_equal(EXTRA_TEXTURE_PATH)
  assert_object(extra.texture_under).is_null()  # 後ろの通常バーが透けて見える
  assert_bool(extra.visible).is_false()
