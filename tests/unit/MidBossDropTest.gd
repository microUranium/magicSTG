# === 中ボスのドロップテスト ===
# 各章の中ボスは撃破時にドロップテーブルを抽選する（章ボスの報酬は別経路で扱うため対象外）
extends GdUnitTestSuite

const MID_BOSSES := [
  "res://scenes/enemy/enemy_boss_bird.tscn",
  "res://scenes/enemy/enemy_boss_stingray.tscn",
  "res://scenes/enemy/enemy_boss_robe.tscn",
  "res://scenes/enemy/enemy_boss_spider.tscn",
  "res://scenes/enemy/enemy_boss_bear.tscn",
]

var _bullet_root: Node2D


func before_test() -> void:
  _bullet_root = auto_free(Node2D.new())
  add_child(_bullet_root)
  TargetService.set_bullet_parent(_bullet_root)


func after_test() -> void:
  TargetService.set_bullet_parent(null)
  for node in _drop_parent().get_children().filter(func(c): return c is DroppedItem):
    node.queue_free()


func _drop_parent() -> Node:
  # LootSystem は current_scene が無いとき root に追加する
  return get_tree().current_scene if get_tree().current_scene else get_tree().root


func _dropped_count() -> int:
  return _drop_parent().get_children().filter(func(c): return c is DroppedItem).size()


func _guaranteed_drop_table() -> Array[DropTableEntry]:
  var entry := DropTableEntry.new()
  entry.prototype = ItemBase.new()
  entry.probability = 1.0
  return [entry]


func test_mid_bosses_drop_on_defeat() -> void:
  for path in MID_BOSSES:
    var boss = (load(path) as PackedScene).instantiate()
    boss.get_node("EnemyAI").skip_dialogue = true
    # 撃破パーティクルは current_scene に追加されるが、テスト実行中は current_scene が無いため生成しない
    boss.destroy_particles_scene = null
    boss.drop_table = _guaranteed_drop_table()
    add_child(boss)
    await await_idle_frame()

    var dropped_before := _dropped_count()
    # 熊は 1 回目の通知で後半フェーズの解禁だけを行うため 2 回通知する（撃破後の通知は無視される）
    boss.on_hp_changed(0, 100)
    boss.on_hp_changed(0, 100)

    assert_int(_dropped_count()).override_failure_message(path).is_equal(dropped_before + 1)
    await await_idle_frame()
