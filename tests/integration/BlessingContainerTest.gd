extends GdUnitTestSuite

const PlayerStubScript := preload("res://tests/stubs/PlayerStub.gd")
const DefensiveBlessing := preload("res://scripts/player/DefensiveBlessing.gd")


func _make_def_shield_res() -> ItemInstanceRes:
  var res := ItemInstanceRes.new()
  res.prototype = _make_blessing_item()
  return res


func _make_blessing_item() -> BlessingItem:
  var proto := BlessingItem.new()
  proto.blessing_scene = _pack_scene(DefensiveBlessing.new())
  proto.base_modifiers = {"shield_hp": 20, "shield_recover_delay": 1.0}
  return proto


func _pack_scene(node: Node) -> PackedScene:
  var ps := PackedScene.new()
  ps.pack(node)
  return ps


# "BlessingContainer がプレイヤー受けダメージを 0 にする"
func test_container_process_damage() -> void:
  var player := PlayerStub.new()
  add_child(player)

  var container := BlessingContainer.new()
  player.add_child(container)
  container.equip_res(_make_def_shield_res())

  var final_dmg := container.process_damage(player, 5)
  assert_int(final_dmg).is_equal(0)
