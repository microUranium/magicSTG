extends GdUnitTestSuite

const ProximityBlessing := preload("res://scripts/player/ProximityBlessing.gd")
const LastStandBlessing := preload("res://scripts/player/LastStandBlessing.gd")
const NullifyBlessing := preload("res://scripts/player/NullifyBlessing.gd")
const BlessingContainerScript := preload("res://scripts/player/BlessingContainer.gd")

var sandbox: Node


# --- 内部スタブ ----------------------------------------------------
class HpStub:
  var current_hp: int = 10
  var max_hp: int = 10


class PlayerStubLS:
  extends Node2D
  var hp_node = HpStub.new()


func _pack_scene(node: Node) -> PackedScene:
  var s := PackedScene.new()
  s.pack(node)
  return s


func _make_item(script: Script, mods: Dictionary) -> ItemInstance:
  var proto := BlessingItem.new()
  proto.id = "test_bless"
  proto.display_name = "テスト加護"
  proto.base_modifiers = mods
  proto.blessing_scene = _pack_scene(script.new())
  return ItemInstance.new(proto)


# enchants: 各要素 [ "res://.../enchantment_*.tres", level ]
func _make_item_enc(script: Script, mods: Dictionary, enchants: Array) -> ItemInstance:
  var inst := _make_item(script, mods)
  for e in enchants:
    inst.add_enchantment(load(e[0]), e[1])
  return inst


func before_test() -> void:
  sandbox = auto_free(Node.new())
  add_child(sandbox)


func after_test() -> void:
  if is_instance_valid(sandbox):
    sandbox.queue_free()


# 近接：距離0で最大ボーナス、range以遠で0
func test_proximity_bonus_by_distance() -> void:
  var inst := _make_item(ProximityBlessing, {"proximity_max_pct": 0.5, "proximity_range": 300.0})
  var bl = inst.prototype.blessing_scene.instantiate()
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(null)

  var player: Node2D = auto_free(Node2D.new())
  var enemy: Node2D = auto_free(Node2D.new())
  sandbox.add_child(player)
  sandbox.add_child(enemy)

  player.global_position = Vector2.ZERO
  enemy.global_position = Vector2.ZERO  # 距離0
  assert_float(bl.get_damage_bonus_pct(player, enemy, {})).is_equal_approx(0.5, 0.001)

  enemy.global_position = Vector2(300, 0)  # range端
  assert_float(bl.get_damage_bonus_pct(player, enemy, {})).is_equal_approx(0.0, 0.001)

  enemy.global_position = Vector2(150, 0)  # 中間 → 半分
  assert_float(bl.get_damage_bonus_pct(player, enemy, {})).is_equal_approx(0.25, 0.001)


# 背水：満タンで0、3割以下で最大
func test_laststand_bonus_by_hp() -> void:
  var inst := _make_item(
    LastStandBlessing, {"laststand_max_pct": 1.5, "laststand_floor_ratio": 0.3}
  )
  var bl = inst.prototype.blessing_scene.instantiate()
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(null)

  var player := PlayerStubLS.new()
  sandbox.add_child(player)

  player.hp_node.max_hp = 10
  player.hp_node.current_hp = 10  # 満タン
  assert_float(bl.get_damage_bonus_pct(player, null, {})).is_equal_approx(0.0, 0.001)

  player.hp_node.current_hp = 3  # 3割 → 最大
  assert_float(bl.get_damage_bonus_pct(player, null, {})).is_equal_approx(1.5, 0.001)

  player.hp_node.current_hp = 1  # 3割未満 → 最大維持
  assert_float(bl.get_damage_bonus_pct(player, null, {})).is_equal_approx(1.5, 0.001)


# 基底値ベースの加算合成：10 + 10*0.5 + 10*0.5 = 20
func test_container_additive_damage_stacking() -> void:
  # コンテナは _ready（savedata読込・親Node2D要求）を避けるためツリーに入れない
  var container = auto_free(BlessingContainerScript.new())

  var player: Node2D = auto_free(Node2D.new())
  var enemy: Node2D = auto_free(Node2D.new())
  sandbox.add_child(player)
  sandbox.add_child(enemy)
  player.global_position = Vector2.ZERO
  enemy.global_position = Vector2.ZERO  # 距離0 → 各 +0.5
  container._player = player

  for _i in range(2):
    var inst := _make_item(ProximityBlessing, {"proximity_max_pct": 0.5, "proximity_range": 300.0})
    var bl = inst.prototype.blessing_scene.instantiate()
    bl.item_inst = inst
    sandbox.add_child(bl)
    bl.on_equip(player)
    container.blessings.append(bl)

  assert_int(container.process_outgoing_damage(enemy, 10)).is_equal(20)


# 打消：発動で敵弾消去シグナル発火・回数減・クールダウン中は再発動不可
func test_nullify_activation_and_cooldown() -> void:
  var inst := _make_item(NullifyBlessing, {"max_uses": 2, "blessing_cooldown_sec": 1.0})
  var bl = inst.prototype.blessing_scene.instantiate()
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(null)

  assert_int(bl.get_uses_remaining()).is_equal(2)

  var emitter = monitor_signals(StageSignals)
  var ok: bool = bl.activate()
  assert_bool(ok).is_true()
  assert_int(bl.get_uses_remaining()).is_equal(1)
  await assert_signal(emitter).wait_until(50).is_emitted("destroy_bullets_by_target", ["players"])

  # クールダウン中は再発動不可（回数は減らない）
  assert_bool(bl.activate()).is_false()
  assert_int(bl.get_uses_remaining()).is_equal(1)


# 無我(L2,+0.30)：近接の最大ダメージ倍率が増える → 距離0で 0.5*(1+0.30)=0.65
func test_proximity_muga_enchant() -> void:
  var inst := _make_item_enc(
    ProximityBlessing,
    {"proximity_max_pct": 0.5, "proximity_range": 300.0},
    [["res://resources/data/enchantment_muga.tres", 2]]
  )
  var bl = inst.prototype.blessing_scene.instantiate()
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(null)

  var player: Node2D = auto_free(Node2D.new())
  var enemy: Node2D = auto_free(Node2D.new())
  sandbox.add_child(player)
  sandbox.add_child(enemy)
  player.global_position = Vector2.ZERO
  enemy.global_position = Vector2.ZERO  # 距離0
  assert_float(bl.get_damage_bonus_pct(player, enemy, {})).is_equal_approx(0.65, 0.001)


# 凝集(L2,+100)：最大ダメージに至る距離が伸びる → range=400, 距離200で t=0.5 → 0.5*0.5=0.25
func test_proximity_gyoshu_enchant() -> void:
  var inst := _make_item_enc(
    ProximityBlessing,
    {"proximity_max_pct": 0.5, "proximity_range": 300.0},
    [["res://resources/data/enchantment_proximity_range_add.tres", 2]]
  )
  var bl = inst.prototype.blessing_scene.instantiate()
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(null)

  var player: Node2D = auto_free(Node2D.new())
  var enemy: Node2D = auto_free(Node2D.new())
  sandbox.add_child(player)
  sandbox.add_child(enemy)
  player.global_position = Vector2.ZERO
  enemy.global_position = Vector2(200, 0)
  assert_float(bl.get_damage_bonus_pct(player, enemy, {})).is_equal_approx(0.25, 0.001)


# 背水：無我(L2)で与ダメ最大1.95、必死(L3,0.5)で最低HP時クールタイム倍率0.5
func test_laststand_muga_and_hisshi() -> void:
  var inst := _make_item_enc(
    LastStandBlessing,
    {"laststand_max_pct": 1.5, "laststand_floor_ratio": 0.3},
    [
      ["res://resources/data/enchantment_muga.tres", 2],
      ["res://resources/data/enchantment_laststand_cdr_pct.tres", 3]
    ]
  )
  var bl = inst.prototype.blessing_scene.instantiate()
  bl.item_inst = inst
  sandbox.add_child(bl)
  bl.on_equip(null)

  var player := PlayerStubLS.new()
  sandbox.add_child(player)
  player.hp_node.max_hp = 10
  player.hp_node.current_hp = 3  # 3割（floor）→ 係数1

  # 無我込みの最大倍率: 1.5*(1+0.30)=1.95
  assert_float(bl.get_damage_bonus_pct(player, null, {})).is_equal_approx(1.95, 0.001)
  # 必死: 1 - 0.5*1 = 0.5
  assert_float(bl.get_attack_cooldown_mult(player)).is_equal_approx(0.5, 0.001)

  # 満タンならクールタイム短縮なし（等倍）
  player.hp_node.current_hp = 10
  assert_float(bl.get_attack_cooldown_mult(player)).is_equal_approx(1.0, 0.001)


# 強奪：敵撃破で確率回復、上限は超えない
# （on_equip の StageSignals 接続は実機で機能。ここでは強奪ロジックを直接検証）
func test_nullify_godatsu() -> void:
  var inst := _make_item_enc(
    NullifyBlessing,
    {"max_uses": 2, "blessing_cooldown_sec": 1.0},
    [["res://resources/data/enchantment_nullify_steal_chance_pct.tres", 3]]
  )
  var bl = inst.prototype.blessing_scene.instantiate()
  bl.item_inst = inst  # setter が _recalc_stats を呼び _steal_chance を確定
  sandbox.add_child(bl)

  # 強奪の確率がエンチャントから読めている（L3=0.10）
  assert_float(bl._steal_chance).is_equal_approx(0.10, 0.001)

  # 上限到達時は撃破しても増えない（確率100%相当に上書きして検証）
  bl.max_uses = 2
  bl._uses_remaining = 2
  bl._steal_chance = 1.0
  bl._on_enemy_defeated(null)
  assert_int(bl.get_uses_remaining()).is_equal(2)  # 超えない

  # 上限未満なら確率100%で回復
  bl._uses_remaining = 1
  bl._on_enemy_defeated(null)
  assert_int(bl.get_uses_remaining()).is_equal(2)
