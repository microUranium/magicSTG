extends GdUnitTestSuite

const BulletStubScript := preload("res://tests/stubs/BulletStub.gd")
const ProjectileCore := preload("res://scripts/player/ProjectileCore.gd")


# ★ AttackCoreItem をメモリ上で生成
func _make_attack_core_item() -> AttackCoreItem:
  var proto := AttackCoreItem.new()
  proto.id = "core_test"
  proto.display_name = "統合テスト用コア"
  proto.damage_base = 10.0
  proto.cooldown_sec_base = 0.2
  proto.base_modifiers = {"bullet_speed": 400.0}
  proto.projectile_scene = _pack_scene(BulletStub.new())
  proto.core_scene = _pack_scene(ProjectileCore.new())
  return proto


# PackedScene へ変換ユーティリティ
func _pack_scene(node: Node) -> PackedScene:
  var s := PackedScene.new()
  s.pack(node)
  return s


# Enchantment 生成
func _enc_speed_up() -> Enchantment:
  var tier := EnchantmentTier.new()
  tier.level = 1
  tier.modifiers = {"bullet_speed_pct": 0.25}  # 速度を 25% 増加

  var e := Enchantment.new()
  e.display_name = "速度+25%"
  e.tiers = [tier]
  return e


# "ProjectileCore に ItemInstance を注入すると弾が生成され、補正値も反映される"
func test_projectile_core_with_instance() -> void:
  var proto := _make_attack_core_item()
  var inst := ItemInstance.new(proto)
  inst.add_enchantment(_enc_speed_up(), 1)

  var core := proto.core_scene.instantiate() as AttackCoreBase
  core.item_inst = inst
  core.set_owner_actor(PlayerStub.new())  # ダミー owner
  core.auto_start = false

  add_child(core)
  core.trigger()  # 1 発撃たせる

  await get_tree().process_frame

  # 子ノードに BulletStub が出たか？
  var bullets: Array[BulletStub] = []
  for node in get_tree().current_scene.get_children():
    if node is BulletStub:
      bullets.append(node)

  assert_int(bullets.size()).is_equal(1)
  var b := bullets[0] as BulletStub

  # ダメージは enchant で変わらず 10、速度は 400 * 1.25
  assert_float(b.damage).is_equal(10.0)
  assert_float(b.speed).is_equal(500.0)
