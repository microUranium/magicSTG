# === bird_a の攻撃をシーン内で個別に持っていることのテスト ===
# 以前は bird_a_rush と共有の single_shot_to_player_straight.tres を使っていた。
# 片方の調整がもう片方に波及しないよう、bird_a は攻撃をシーン内で持つ
# テスト対象:
#   1. bird_a の攻撃は bird_a_rush の攻撃と別のリソース
#   2. bird_a_rush は引き続き共有の攻撃を使う
extends GdUnitTestSuite

const BIRD_A := preload("res://scenes/enemy/enemy_bird_a.tscn")
const BIRD_A_RUSH := preload("res://scenes/enemy/enemy_bird_a_rush.tscn")
const SHARED_PATTERN := "res://resources/attackPatterns/single_shot_to_player_straight.tres"


func _pattern(scene: PackedScene) -> AttackPattern:
  var enemy: Node = auto_free(scene.instantiate())
  return enemy.get_node("AttackCoreSlot").attack_pattern


func test_bird_a_has_own_attack_pattern() -> void:
  var bird_a := _pattern(BIRD_A)
  var rush := _pattern(BIRD_A_RUSH)

  assert_object(bird_a).is_not_null()
  assert_object(bird_a).is_not_same(rush)
  assert_str(bird_a.resource_path).is_not_equal(SHARED_PATTERN)
  assert_object(bird_a.bullet_scene).is_not_null()


func test_bird_a_rush_keeps_shared_pattern() -> void:
  assert_str(_pattern(BIRD_A_RUSH).resource_path).is_equal(SHARED_PATTERN)
