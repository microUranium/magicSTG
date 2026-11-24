# === 被弾時の反撃（CounterAttackAI）のクールタイムのテスト ===
# テスト対象:
#   1. 反撃してから counter_cooldown_sec が過ぎるまでは、被弾しても反撃しない（効果音も鳴らさない）
#   2. クールタイムが過ぎると、次の被弾で反撃する
#   3. counter_cooldown_sec = 0 なら被弾のたびに反撃する
#   4. living_wood の盾にクールタイムが設定されている
# クールタイムは調整で変わるため、期待値は counter_cooldown_sec から求める
extends GdUnitTestSuite

const SHIELD := preload("res://scenes/enemy/enemy_living_wood_shield.tscn")

var _world: Node2D
var _shield: Node2D
var _ai: CounterAttackAI
var _counter_count := 0


func before_test() -> void:
  _world = Node2D.new()
  add_child(_world)
  TargetService.set_bullet_parent(_world)
  _counter_count = 0
  _shield = SHIELD.instantiate()
  _shield.show_damage_numbers = false
  _world.add_child(_shield)
  _ai = _shield.get_node("CounterAttackAI")
  _ai.set_process(false)  # 時間はテストから手動で進める
  StageSignals.sfx_play_requested.connect(_on_sfx)


func after_test() -> void:
  if StageSignals.sfx_play_requested.is_connected(_on_sfx):
    StageSignals.sfx_play_requested.disconnect(_on_sfx)
  TargetService.set_bullet_parent(null)
  _world.free()


func _on_sfx(sfx_name, _pos, _a, _b) -> void:
  if sfx_name == _ai.counter_sfx:
    _counter_count += 1


func test_shield_has_counter_cooldown() -> void:
  assert_float(_ai.counter_cooldown_sec).is_greater(0.0)


func test_no_counter_during_cooldown() -> void:
  var cooldown := _ai.counter_cooldown_sec
  _shield.take_damage(1)
  _shield.take_damage(1)
  _shield.take_damage(1)
  assert_int(_counter_count).is_equal(1)

  _ai._process(cooldown * 0.9)
  _shield.take_damage(1)
  assert_int(_counter_count).is_equal(1)


func test_counters_again_after_cooldown() -> void:
  var cooldown := _ai.counter_cooldown_sec
  _shield.take_damage(1)

  _ai._process(cooldown)
  _shield.take_damage(1)

  assert_int(_counter_count).is_equal(2)


func test_counters_every_hit_without_cooldown() -> void:
  _ai.counter_cooldown_sec = 0.0

  _shield.take_damage(1)
  _shield.take_damage(1)
  _shield.take_damage(1)

  assert_int(_counter_count).is_equal(3)
