# === bird_a の攻撃をシーン内で個別に持っていることのテスト ===
# 以前は bird_a_rush と共有のファイル（single_shot_to_player_straight.tres、削除済み）を使っていた。
# 片方の調整がもう片方に波及しないよう、bird_a は攻撃をシーン内で持つ
# テスト対象:
#   1. bird_a の攻撃は bird_a_rush の攻撃と別のリソース
#   2. bird_a_rush は攻撃しない（突進のみ）
extends GdUnitTestSuite

const BIRD_A := preload("res://scenes/enemy/enemy_bird_a.tscn")
const BIRD_A_RUSH := preload("res://scenes/enemy/enemy_bird_a_rush.tscn")


func _pattern(scene: PackedScene) -> AttackPattern:
  var enemy: Node = auto_free(scene.instantiate())
  return enemy.get_node("AttackCoreSlot").attack_pattern


func test_bird_a_has_own_attack_pattern() -> void:
  var bird_a := _pattern(BIRD_A)
  var rush := _pattern(BIRD_A_RUSH)

  assert_object(bird_a).is_not_null()
  assert_object(bird_a).is_not_same(rush)
  # シーン内のリソース（外部ファイルではない）
  var path := bird_a.resource_path
  assert_bool(path.is_empty() or path.contains("::")).is_true()
  assert_object(bird_a.bullet_scene).is_not_null()


func test_bird_a_rush_does_not_shoot() -> void:
  assert_object(_pattern(BIRD_A_RUSH)).is_null()
