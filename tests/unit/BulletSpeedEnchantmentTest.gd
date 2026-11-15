# === エンチャント「加速」(bullet_speed_pct) 機能テスト ===
# テスト対象:
#   1. ティア値・説明文と付与先（トリプルバーストのみ）
#   2. トリプルバーストの弾速が Lv1〜3 で 1440 / 1800 / 2400 になる（基本 1200）
#   3. 再計算しても弾速が増えない
#   4. 撃った弾にその弾速が渡る
extends GdUnitTestSuite

const SPEED_PATH := "res://resources/data/enchantment_bullet_speed_pct.tres"
const TRIPLE_PATH := "res://resources/data/attackcore_triple_burst.tres"
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")

var _saved_rect: Rect2


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = Rect2(-5000, -5000, 10000, 10000)


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  TargetService.set_bullet_parent(null)


func _make_inst(level: int) -> ItemInstance:
  var inst := ItemInstance.new(load(TRIPLE_PATH))
  if level > 0:
    inst.add_enchantment(load(SPEED_PATH), level)
  return inst


func _make_pattern(inst: ItemInstance) -> AttackPattern:
  var pattern := PlayerAttackPatternFactory.create_pattern_from_item_instance(inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  return pattern


func test_enchantment_data() -> void:
  var enchant: Enchantment = load(SPEED_PATH)
  assert_str(str(enchant.id)).is_equal("bullet_speed_pct")
  assert_str(enchant.display_name).is_equal("加速")
  assert_str(enchant.description).is_equal("弾速が上がります。")
  var expected := {1: 0.2, 2: 0.5, 3: 1.0}
  for level in expected:
    var value := float(enchant.get_modifiers(level)["bullet_speed_pct"])
    assert_float(value).is_equal_approx(expected[level], 0.0001)


func test_only_triple_burst_allows_speed() -> void:
  var enchant: Enchantment = load(SPEED_PATH)
  for path in DirAccess.get_files_at("res://resources/data"):
    if not (path.begins_with("attackcore_") or path.begins_with("blessing_")):
      continue
    if not path.ends_with(".tres"):
      continue
    var item: ItemBase = load("res://resources/data/" + path)
    var expected := path == "attackcore_triple_burst.tres"
    assert_bool(item.allows_enchantment(enchant)).override_failure_message(path).is_equal(expected)


func test_triple_burst_speed_per_level() -> void:
  var expected := {0: 1200.0, 1: 1440.0, 2: 1800.0, 3: 2400.0}
  for level in expected:
    var speed := _make_pattern(_make_inst(level)).bullet_speed
    var label := "Lv%d" % level
    assert_float(speed).override_failure_message(label).is_equal_approx(expected[level], 0.001)


func test_speed_update_is_idempotent() -> void:
  var inst := _make_inst(3)
  var pattern := _make_pattern(inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)

  assert_float(pattern.bullet_speed).is_equal_approx(2400.0, 0.001)


func test_fired_bullet_uses_enchanted_speed() -> void:
  var parent: Node2D = auto_free(Node2D.new())
  add_child(parent)
  TargetService.set_bullet_parent(parent)
  var fairy: Node2D = auto_free(Node2D.new())
  add_child(fairy)
  var core = auto_free(load("res://scenes/attackCores/universal_attack_core.tscn").instantiate())
  core.player_mode = true
  core.show_gauge_ui = false
  core.auto_start = false
  core.item_inst = _make_inst(3)
  fairy.add_child(core)
  core.set_owner_actor(fairy)
  core._cooling = false

  core.trigger()
  await get_tree().process_frame

  var bullets := parent.get_children().filter(func(n): return n is ProjectileBullet)
  assert_int(bullets.size()).is_greater(0)
  assert_float(bullets[0].speed).is_equal_approx(2400.0, 0.001)
