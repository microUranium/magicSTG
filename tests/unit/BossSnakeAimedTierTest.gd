# === boss_snake の各節の「HP に応じて間隔が短くなる自機狙い弾」のテスト ===
# テスト対象:
#   1. HP の割合ごとに、その段階（BossSnakeBodyAI.AIMED_TIERS）の範囲の間隔で撃つ
#   2. 弾はプレイヤー狙いの直進弾（弾速・ダメージは AIMED_TIER_SPEED / AIMED_TIER_DAMAGE）
#   3. フェーズが変わって他の攻撃が切り替わっても、この攻撃のコアは残る
#   4. 登場と会話の間（フェーズ0・1）は撃たず、戦闘（フェーズ2）が始まってから撃ち始める
#   5. 全節が同時に撃ち始めないよう、最初の1発までの待ち時間が節ごとにずれている
#   6. 段階が変わったとき、新しい間隔より長い待ちが残っている節は、待ちが新しい間隔の中に縮む
# 段階の境目と間隔は調整で変わるため、期待値は AIMED_TIERS から求める
extends GdUnitTestSuite

const BOSS_SNAKE := preload("res://scenes/enemy/enemy_boss_snake.tscn")
const BODY_AI := preload("res://scripts/enemy/BossSnakeBodyAI.gd")
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 960)

var _saved_rect: Rect2
var _saved_scene: Node
var _saved_player: Node2D
var _world: Node2D
var _boss: Node2D
var _hp: Node


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _saved_scene = get_tree().current_scene
  _world = Node2D.new()
  get_tree().root.add_child(_world)
  get_tree().current_scene = _world
  TargetService.set_bullet_parent(_world)
  _saved_player = TargetService.get_player()
  var player := Node2D.new()
  _world.add_child(player)
  player.global_position = Vector2(448, 800)
  TargetService.register_player(player)

  _boss = BOSS_SNAKE.instantiate()
  _world.add_child(_boss)
  _boss.global_position = Vector2(448, 200)
  _boss.setup()
  _hp = _boss.get_node("HpNode")
  await await_idle_frame()
  await await_idle_frame()


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  if is_instance_valid(_saved_player):
    TargetService.register_player(_saved_player)
  else:
    TargetService.unregister_player()
  TargetService.set_bullet_parent(null)
  get_tree().current_scene = _saved_scene
  _world.free()


## 登場と会話を終えて戦闘（フェーズ2）を始める
func _start_battle() -> void:
  _boss.ai._phase_idx = 1
  _boss.ai._next_phase()


## 頭のすぐ後ろの節の AI（HP が減っても最後まで壊れない）
func _front_ai() -> Node:
  return _boss.segment_manager.get_all_segments()[0].get_node("EnemyAI")


func _set_hp_ratio(ratio: float) -> void:
  _hp.take_damage(_hp.current_hp - floori(_hp.max_hp * ratio))


func test_not_fired_before_battle_starts() -> void:
  var ai := _front_ai()
  assert_object(ai._aimed_tier_core).is_null()

  _start_battle()

  assert_object(ai._aimed_tier_core).is_not_null()
  assert_int(ai._aimed_tier_idx).is_equal(0)


func test_interval_follows_hp_tier() -> void:
  _start_battle()
  var ai := _front_ai()
  var tiers: Array = BODY_AI.AIMED_TIERS
  var upper := 1.0
  for i in tiers.size():
    # その段階の中ほどの HP にする
    _set_hp_ratio((upper + tiers[i].down_to) / 2.0)
    var core: UniversalAttackCore = ai._aimed_tier_core
    assert_int(ai._aimed_tier_idx).is_equal(i)
    assert_float(core.attack_pattern.burst_delay).is_between(tiers[i].min, tiers[i].max)
    assert_float(core.cooldown_sec).is_equal(core.attack_pattern.burst_delay)
    upper = tiers[i].down_to


func test_tier_boundary_is_inclusive_like_phase_changes() -> void:
  # 境目ちょうど（以下）で次の段階に入る
  var tiers: Array = BODY_AI.AIMED_TIERS
  assert_int(BODY_AI.aimed_tier_index_for(1.0)).is_equal(0)
  assert_int(BODY_AI.aimed_tier_index_for(tiers[0].down_to)).is_equal(1)
  assert_int(BODY_AI.aimed_tier_index_for(0.0)).is_equal(tiers.size() - 1)


func test_fires_aimed_straight_bullet() -> void:
  _start_battle()
  var pattern: AttackPattern = _front_ai()._aimed_tier_core.attack_pattern
  assert_int(pattern.direction_type).is_equal(AttackPattern.DirectionType.TO_PLAYER)
  assert_float(pattern.bullet_speed).is_equal(BODY_AI.AIMED_TIER_SPEED)
  assert_int(pattern.damage).is_equal(BODY_AI.AIMED_TIER_DAMAGE)
  assert_object(pattern.bullet_movement_config).is_null()
  assert_str(pattern.bullet_visual_config.texture.resource_path).ends_with(
    "bullet_snake_scale_white.png"
  )
  assert_bool(pattern.auto_start).is_true()


func test_core_kept_across_body_attack_changes() -> void:
  _start_battle()
  var ai := _front_ai()
  var core = ai._aimed_tier_core

  ai._setup_attack(3)  # HP 30% 以下の攻撃に切り替わる

  assert_bool(is_instance_valid(core)).is_true()
  assert_bool(ai.attack_core_slot.get_active_cores().has(core)).is_true()


func test_first_shots_are_staggered() -> void:
  _start_battle()

  var waits := []
  for segment in _boss.segment_manager.get_all_segments():
    var core: UniversalAttackCore = segment.get_node("EnemyAI")._aimed_tier_core
    var wait: float = core._cool_timer.time_left
    assert_float(wait).is_less_equal(core.cooldown_sec)  # 間隔より長くは待たない
    waits.append(wait)
  # 節ごとに 0〜間隔 の範囲でずれる（揃っていれば差はほぼ 0）
  var first_tier: Dictionary = BODY_AI.AIMED_TIERS[0]
  assert_float(waits.max() - waits.min()).is_greater(first_tier.min / 2.0)


func test_long_wait_is_shortened_when_tier_changes() -> void:
  _start_battle()
  var tiers: Array = BODY_AI.AIMED_TIERS
  var segments: Array = _boss.segment_manager.get_all_segments()
  var long_core: UniversalAttackCore = segments[0].get_node("EnemyAI")._aimed_tier_core
  var short_core: UniversalAttackCore = segments[1].get_node("EnemyAI")._aimed_tier_core
  long_core.restart_cooldown(tiers[0].max)  # 前の段階の長い待ちが残っている
  var short_wait: float = tiers[1].min / 2.0
  short_core.restart_cooldown(short_wait)  # 新しい段階の間隔より短い待ち

  _set_hp_ratio((tiers[0].down_to + tiers[1].down_to) / 2.0)  # 次の段階へ

  assert_float(long_core.get_cooldown_time_left()).is_less_equal(long_core.cooldown_sec)
  assert_float(long_core.cooldown_sec).is_between(tiers[1].min, tiers[1].max)
  # 短い待ちはそのまま（縮めない）
  assert_float(short_core.get_cooldown_time_left()).is_equal_approx(short_wait, 0.1)
