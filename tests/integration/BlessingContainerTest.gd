extends GdUnitTestSuite

const PlayerStubScript := preload("res://tests/stubs/PlayerStub.gd")
const DefensiveBlessing := preload("res://scripts/player/DefensiveBlessing.gd")

# BlessingContainer は _ready で PlayerSaveData の装備中の加護を読み込む。
# 実際のセーブデータ（遊んだときに装備した加護）に結果が左右されないよう、テスト中は空にする
var _saved_blessings: Array[ItemInstance] = []


func before_test() -> void:
  _saved_blessings.assign(PlayerSaveData.get_blessings())
  PlayerSaveData.set_blessings([] as Array[ItemInstance])


func after_test() -> void:
  PlayerSaveData.set_blessings(_saved_blessings)


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
  # セーブデータの加護は読み込まれず、テストで装備した加護だけがある
  assert_int(container.blessings.size()).is_equal(1)

  var final_dmg := container.process_damage(player, 5)
  assert_int(final_dmg).is_equal(0)
