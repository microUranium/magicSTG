extends GdUnitTestSuite

const PlayerStubScript := preload("res://tests/stubs/PlayerStub.gd")
const DefensiveBlessing := preload("res://scripts/player/DefensiveBlessing.gd")
var sandbox: Node


func _make_blessing_item(modifiers: Dictionary = {}) -> BlessingItem:
  var base := {"shield_hp": 50, "shield_recover_delay": 0.2}
  base.merge(modifiers, true)  # 引数で上書き
  var proto := BlessingItem.new()
  proto.id = "bless_shield"
  proto.display_name = "防壁の加護"
  proto.base_modifiers = base
  proto.blessing_scene = _pack_scene(DefensiveBlessing.new())
  return proto


func _equip_blessing(modifiers: Dictionary = {}) -> DefensiveBlessing:
  sandbox = auto_free(Node.new())
  add_child(sandbox)
  var p := PlayerStub.new()
  sandbox.add_child(p)

  var inst := ItemInstance.new(_make_blessing_item(modifiers))
  var bl := inst.prototype.blessing_scene.instantiate() as DefensiveBlessing
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(p)
  return bl


func _pack_scene(node: Node) -> PackedScene:
  var s := PackedScene.new()
  s.pack(node)
  return s


# "シールドが HP を肩代わりし、破壊後はダメージが通る"
func test_shield_absorb_and_break() -> void:
  # ① セットアップ
  sandbox = auto_free(Node.new())
  add_child(sandbox)
  var p := PlayerStub.new()
  sandbox.add_child(p)

  var inst := ItemInstance.new(_make_blessing_item())
  var bl := inst.prototype.blessing_scene.instantiate() as DefensiveBlessing
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(p)

  # ② 40 ダメージ → シールド残 10
  var dmg: int = bl.process_damage(p, 40)
  assert_int(dmg).is_equal(0)  # 吸収
  assert_int(bl.shield_current).is_equal(10)

  # ③ 15 ダメージ → シールド破壊（残 -5）
  dmg = bl.process_damage(p, 15)
  assert_int(dmg).is_equal(0)  # 破壊時も 0
  assert_bool(bl.is_broken).is_true()

  # ④ 以降ダメージは通る
  dmg = bl.process_damage(p, 10)
  assert_int(dmg).is_equal(10)

  # ⑤ 復活タイマー経過でシールド全快
  await get_tree().create_timer(0.25).timeout
  assert_bool(bl.is_broken).is_false()
  assert_int(bl.shield_current).is_equal(bl.shield_max)


# 破壊されていない時、無被弾が続くとシールドが徐々に回復する
func test_natural_regen_after_delay() -> void:
  var bl := _equip_blessing({"shield_regen_delay": 0.1, "shield_regen_rate": 50.0})

  # 40 ダメージ → シールド残 10（未破壊）
  bl.process_damage(bl.player_ref, 40)
  assert_int(bl.shield_current).is_equal(10)
  assert_bool(bl.is_broken).is_false()

  # regen_delay(0.1s) 経過後、徐々に回復する
  await await_millis(400)
  assert_int(bl.shield_current).is_greater(10)


# 被弾し続ける（直前まで被弾）と自然回復は始まらない
func test_natural_regen_blocked_by_recent_damage() -> void:
  var bl := _equip_blessing({"shield_regen_delay": 1.0, "shield_regen_rate": 50.0})

  bl.process_damage(bl.player_ref, 40)
  assert_int(bl.shield_current).is_equal(10)

  # regen_delay(1.0s) 未満しか待たない → 回復していない
  await await_millis(200)
  assert_int(bl.shield_current).is_equal(10)


# 破壊時は復活ゲージスタイルへ、復活後は通常スタイルへ戻る
func test_gauge_style_switches_on_break_and_recover() -> void:
  var bl := _equip_blessing({"shield_recover_delay": 0.2})

  assert_str(bl.gauge_style).is_equal("durability")

  bl.process_damage(bl.player_ref, 60)  # 破壊
  assert_bool(bl.is_broken).is_true()
  assert_str(bl.gauge_style).is_equal("durability_recovering")

  # 復活後は通常スタイルへ
  await await_millis(300)
  assert_bool(bl.is_broken).is_false()
  assert_str(bl.gauge_style).is_equal("durability")


# 破壊中、復活ゲージが時間経過で 0→max へ充填される
func test_recover_gauge_fills_over_time() -> void:
  var bl := _equip_blessing({"shield_recover_delay": 0.5})

  bl.process_damage(bl.player_ref, 60)  # 破壊
  assert_bool(bl.is_broken).is_true()

  # 復活途中：ゲージは 0 より大きく max 未満
  await await_millis(200)
  assert_bool(bl.is_broken).is_true()
  assert_float(bl.gauge_current).is_greater(0.0)
  assert_float(bl.gauge_current).is_less(float(bl.shield_max))


func after():
  # sandbox は auto_free 管理のため、有効な場合のみ明示解放
  if is_instance_valid(sandbox):
    sandbox.queue_free()
