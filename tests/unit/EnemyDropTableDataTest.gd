# === 敵のドロップテーブルのデータテスト ===
# 敵シーンに設定したドロップエントリが読み込めて、抽選に使える値になっていることを確認する
extends GdUnitTestSuite

const ENEMY_DIR := "res://scenes/enemy"


func _enemy_scenes_with_drops() -> Array[Node]:
  var out: Array[Node] = []
  for file in DirAccess.get_files_at(ENEMY_DIR):
    if not file.ends_with(".tscn"):
      continue
    var node := auto_free((load("%s/%s" % [ENEMY_DIR, file]) as PackedScene).instantiate()) as Node
    if node is EnemyBase and not node.drop_table.is_empty():
      out.append(node)
  return out


func test_enemy_drop_entries_are_valid() -> void:
  var enemies := _enemy_scenes_with_drops()
  assert_int(enemies.size()).is_greater(0)
  for enemy in enemies:
    for entry in enemy.drop_table:
      var label := "%s: %s" % [enemy.scene_file_path, entry.resource_path]
      assert_object(entry).override_failure_message(label).is_not_null()
      assert_object(entry.prototype).override_failure_message(label).is_not_null()
      assert_float(entry.probability).override_failure_message(label).is_greater(0.0)
      assert_float(entry.probability).override_failure_message(label).is_less_equal(1.0)
      assert_object(entry.enchant_rule).override_failure_message(label).is_not_null()


func test_enchant_rules_can_roll_for_their_items() -> void:
  for enemy in _enemy_scenes_with_drops():
    for entry in enemy.drop_table:
      var rule: EnchantmentRule = entry.enchant_rule
      # 許可エンチャントで絞り込んだ候補が空だと、常にエンチャントなしになる
      var candidates := rule.pool.filter(
        func(enc: Enchantment) -> bool: return entry.prototype.allows_enchantment(enc)
      )
      (
        assert_int(candidates.size())
        . override_failure_message("%s: no enchantment can roll" % entry.resource_path)
        . is_greater(0)
      )
      for count in rule.count_weights:
        assert_int(int(count)).is_between(0, LootSystem.enchantment_max_count)
