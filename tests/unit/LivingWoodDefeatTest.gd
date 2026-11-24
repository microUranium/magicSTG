# === living_wood の撃破時の通知のテスト ===
# living_wood は盾を消すために撃破の処理を独自に持っている。その中でも、共通の撃破の処理と同じく
# 撃破のシグナル（destroyed）と「敵を倒した」通知（StageSignals.enemy_defeated）を1回ずつ出すことを確認する
extends GdUnitTestSuite

const LIVING_WOOD := preload("res://scenes/enemy/enemy_living_wood.tscn")

var _world: Node2D
var _wood: EnemyLivingWood
var _defeated: Array = []
var _destroyed_count := 0


func before_test() -> void:
  _world = Node2D.new()
  add_child(_world)
  _defeated.clear()
  _destroyed_count = 0
  _wood = LIVING_WOOD.instantiate()
  _wood.destroy_particles_scene = null
  _wood.drop_table.clear()
  _world.add_child(_wood)
  _wood.destroyed.connect(func(): _destroyed_count += 1)
  StageSignals.enemy_defeated.connect(_on_enemy_defeated)


func after_test() -> void:
  if StageSignals.enemy_defeated.is_connected(_on_enemy_defeated):
    StageSignals.enemy_defeated.disconnect(_on_enemy_defeated)
  _world.free()


func _on_enemy_defeated(enemy) -> void:
  _defeated.append(enemy)


func test_emits_destroyed_and_enemy_defeated_once_on_death() -> void:
  var hp: Node = _wood.get_node("HpNode")

  hp.take_damage(hp.max_hp)
  hp.take_damage(1)  # 同じフレームで続けて当たっても二重に通知しない

  assert_int(_destroyed_count).is_equal(1)
  assert_int(_defeated.size()).is_equal(1)
  assert_object(_defeated[0]).is_same(_wood)


func test_shields_removed_on_death() -> void:
  var hp: Node = _wood.get_node("HpNode")
  var shields := _wood.shield_instances.duplicate()
  assert_int(shields.size()).is_greater(0)

  hp.take_damage(hp.max_hp)

  for s in shields:
    assert_bool(s.is_queued_for_deletion()).is_true()
