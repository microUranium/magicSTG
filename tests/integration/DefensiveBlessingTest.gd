extends GdUnitTestSuite

const PlayerStubScript := preload("res://tests/stubs/PlayerStub.gd")
const DefensiveBlessing := preload("res://scripts/player/DefensiveBlessing.gd")
var sandbox: Node


func _make_blessing_item() -> BlessingItem:
  var proto := BlessingItem.new()
  proto.id = "bless_shield"
  proto.display_name = "防壁の加護"
  proto.base_modifiers = {"shield_hp": 50, "shield_recover_delay": 0.2}
  proto.blessing_scene = _pack_scene(DefensiveBlessing.new())
  return proto


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


func after():
  sandbox.queue_free()  # クリーンアップ
