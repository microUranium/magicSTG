# === エンチャント「反撃」(counter_damage_pct) 機能テスト ===
# テスト対象:
#   1. ティア値と付与先（背水・体力増強・近接）
#   2. 被弾していないときはボーナス 0
#   3. 被弾後の効果時間内は Lv1〜3 で +50% / +100% / +200%（命中時の与ダメージ計算に乗る）
#   4. 効果時間が切れるとボーナス 0 に戻る
#   5. 効果時間内に再び被弾すると効果時間が戻る（ボーナスは重ならない）
#   6. ダメージ 0（シールドが受け止めた等）では発動しない
#   7. 近接に付けたとき、近接の元の補正と反撃の両方が乗る
#   8. BlessingContainer の装備・解除で被弾の監視が付け外しされる
extends GdUnitTestSuite

const LastStandBlessing := preload("res://scripts/player/LastStandBlessing.gd")
const ProximityBlessing := preload("res://scripts/player/ProximityBlessing.gd")
const COUNTER_PATH := "res://resources/data/enchantment_counter_damage_pct.tres"


class MockPlayer:
  extends Node2D
  signal damage_received(damage)
  var hp_node = null  # 背水の体力判定は 0（満タン扱い）になる


func _make_player() -> MockPlayer:
  var player: MockPlayer = auto_free(MockPlayer.new())
  add_child(player)
  return player


func _make_inst(base_modifiers: Dictionary, level: int) -> ItemInstance:
  var proto := BlessingItem.new()
  proto.id = "test_blessing"
  proto.display_name = "テスト加護"
  proto.base_modifiers = base_modifiers
  var inst := ItemInstance.new(proto)
  if level > 0:
    var counter: Enchantment = load(COUNTER_PATH)
    inst.enchantments[counter] = level
  return inst


## 背水の加護に反撃を付けて装備する（被弾の監視まで済ませる）
func _equip_laststand(player: Node, level: int) -> BlessingBase:
  var blessing: BlessingBase = auto_free(LastStandBlessing.new())
  add_child(blessing)  # 効果時間のタイマーを動かすためツリーに入れる
  blessing.item_inst = _make_inst({"laststand_max_pct": 1.5, "laststand_floor_ratio": 0.3}, level)
  blessing.on_equip(player)
  blessing.setup_counter(player)
  return blessing


## ツリーに入れない（_ready のセーブデータ読み込みを走らせない）容器
func _make_container(player: Node, list: Array) -> BlessingContainer:
  var container: BlessingContainer = auto_free(BlessingContainer.new())
  container._player = player
  var typed: Array[BlessingBase] = []
  for b in list:
    typed.append(b)
  container.blessings = typed
  return container


func test_enchantment_data() -> void:
  var enchant: Enchantment = load(COUNTER_PATH)
  assert_str(str(enchant.id)).is_equal("counter_damage_pct")
  assert_str(enchant.display_name).is_equal("反撃")
  assert_str(enchant.description).is_equal("ダメージを受けると、一定時間攻撃力が増加します。")
  var expected := {1: 0.5, 2: 1.0, 3: 2.0}
  for level in expected:
    var value := float(enchant.get_modifiers(level)["counter_damage_pct"])
    assert_float(value).is_equal_approx(expected[level], 0.0001)

  var allowed_items := ["blessing_laststand", "blessing_hp_boost", "blessing_proximity"]
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
    assert_bool(allowed).override_failure_message(item_id).is_equal(item_id in allowed_items)


func test_no_bonus_before_damage() -> void:
  var player := _make_player()
  var blessing := _equip_laststand(player, 1)

  assert_float(blessing.get_counter_bonus_pct()).is_equal_approx(0.0, 0.0001)
  assert_int(_make_container(player, [blessing]).process_outgoing_damage(null, 2)).is_equal(2)


func test_bonus_applies_on_hit_after_damage() -> void:
  # 2 ダメージの弾が命中したとき：+50% → 3、+100% → 4、+200% → 6
  var expected := {1: [0.5, 3], 2: [1.0, 4], 3: [2.0, 6]}
  for level in expected:
    var player := _make_player()
    var blessing := _equip_laststand(player, level)
    var container := _make_container(player, [blessing])

    player.damage_received.emit(3)

    assert_float(blessing.get_counter_bonus_pct()).is_equal_approx(expected[level][0], 0.0001)
    assert_int(container.process_outgoing_damage(null, 2)).is_equal(expected[level][1])


func test_bonus_ends_after_duration() -> void:
  var player := _make_player()
  var blessing := _equip_laststand(player, 1)
  player.damage_received.emit(3)
  assert_float(blessing._counter_timer.wait_time).is_equal_approx(0.67, 0.0001)

  await blessing._counter_timer.timeout

  assert_float(blessing.get_counter_bonus_pct()).is_equal_approx(0.0, 0.0001)


func test_damage_during_effect_resets_duration_without_stacking() -> void:
  var player := _make_player()
  var blessing := _equip_laststand(player, 1)
  player.damage_received.emit(3)
  blessing._counter_timer.start(0.1)  # 効果時間の残りが少ない状態を作る

  player.damage_received.emit(3)

  assert_float(blessing._counter_timer.time_left).is_greater(0.6)  # 0.67 秒に戻る
  assert_float(blessing.get_counter_bonus_pct()).is_equal_approx(0.5, 0.0001)  # 重ならない


func test_zero_damage_does_not_trigger() -> void:
  var player := _make_player()
  var blessing := _equip_laststand(player, 1)

  player.damage_received.emit(0)  # シールドが受け止めた

  assert_float(blessing.get_counter_bonus_pct()).is_equal_approx(0.0, 0.0001)


func test_proximity_bonus_and_counter_both_apply() -> void:
  var player := _make_player()
  player.global_position = Vector2(0, 0)
  var enemy: Node2D = auto_free(Node2D.new())
  add_child(enemy)
  enemy.global_position = Vector2(0, 150)  # 有効距離 300 の半分 → 近接 +25%

  var blessing: BlessingBase = auto_free(ProximityBlessing.new())
  add_child(blessing)
  blessing.item_inst = _make_inst({"proximity_max_pct": 0.5, "proximity_range": 300.0}, 1)
  blessing.on_equip(player)
  blessing.setup_counter(player)
  var container := _make_container(player, [blessing])

  assert_int(container.process_outgoing_damage(enemy, 4)).is_equal(5)  # 4 × 1.25
  player.damage_received.emit(3)
  assert_int(container.process_outgoing_damage(enemy, 4)).is_equal(7)  # 4 × (1 + 0.25 + 0.5)


func test_container_wires_and_unwires_counter() -> void:
  var player := _make_player()
  var container: BlessingContainer = auto_free(BlessingContainer.new())
  container._player = player  # ツリーに入れない（セーブデータの加護を読み込ませない）
  var proto := BlessingItem.new()
  proto.id = "test_laststand"
  proto.base_modifiers = {"laststand_max_pct": 1.5}
  var packed := PackedScene.new()
  packed.pack(LastStandBlessing.new())
  proto.blessing_scene = packed
  var inst := ItemInstance.new(proto)
  var counter: Enchantment = load(COUNTER_PATH)
  inst.enchantments[counter] = 2

  container.equip_instance(inst)
  var blessing: BlessingBase = container.blessings[0]
  assert_bool(player.damage_received.is_connected(blessing._on_counter_damage_received)).is_true()

  container.unequip_all()
  assert_bool(player.damage_received.is_connected(blessing._on_counter_damage_received)).is_false()
