extends GdUnitTestSuite

var _scene_root: Node2D


## ---------- 共通セットアップ ----------
func before() -> void:
  _scene_root = auto_free(Node2D.new())
  get_tree().set_current_scene(_scene_root)  # LootSystem は current_scene を参照するため


func before_test() -> void:
  # テスト前に毎回実行される
  for node in get_tree().current_scene.get_children().filter(func(c): return c is DroppedItem):
    node.queue_free()  # 前のテストで生成された DroppedItem を削除


## ---------- 1-1. 100% ドロップ確認 ----------
func test_spawn_drop_creates_dropped_item() -> void:
  # ダミー ItemBase
  var proto := ItemBase.new()
  proto.item_type = ItemBase.ItemType.ATTACK_CORE

  var entry := DropTableEntry.new()
  entry.prototype = proto
  entry.probability = 1.0  # 必ず落ちる
  entry.enchant_rule = null  # 今回は不要

  LootSystem.spawn_drop(Vector2.ZERO, [entry])
  await get_tree().process_frame

  # DroppedItem が 1 個追加され、ItemInstance の prototype が一致すること
  var drops := get_tree().current_scene.get_children().filter(func(c): return c is DroppedItem)
  assert_int(drops.size()).is_equal(1)
  assert_object(drops[0].item_instance.prototype).is_equal(proto)


## ---------- 1-2. 不要ドロップ確認 ----------
func test_spawn_drop_probability_zero_spawns_nothing() -> void:
  var proto := ItemBase.new()
  var entry := DropTableEntry.new()
  entry.prototype = proto
  entry.probability = 0.0  # 絶対に落ちない

  LootSystem.spawn_drop(Vector2.ZERO, [entry])
  await get_tree().process_frame

  var drops := get_tree().current_scene.get_children().filter(func(c): return c is DroppedItem)
  assert_int(drops.size()).is_equal(0)
