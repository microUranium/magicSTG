# === boss_bird_swamp のテスト ===
# テスト対象:
#   1. フェーズ5に入った時点の自機狙い弾は1方向（フェーズ3と同じ）
#   2. HP が phase5_spread_hp_ratio を上回っている間は1方向のまま
#   3. HP が phase5_spread_hp_ratio 以下になると、自機狙い弾がすべて3方向の扇になる。全周の連射は変わらない
#   4. フェーズ8・9の「突進 → 減速」で、残像と突進のアニメーション（体当たりの当たり判定）は突進の間だけ
# 割合は調整で変わるため、期待値は phase5_spread_hp_ratio から求める
extends GdUnitTestSuite

const BOSS := preload("res://scenes/enemy/enemy_boss_bird_swamp.tscn")
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 896)

var _saved_rect: Rect2
var _saved_scene: Node
var _world: Node2D
var _boss: Node2D
var _ai: BossBirdSwampAI
var _hp: Node


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _saved_scene = get_tree().current_scene
  # 分身の火の玉は current_scene に追加されるため、テスト用の world を current_scene にする
  _world = Node2D.new()
  get_tree().root.add_child(_world)
  get_tree().current_scene = _world
  TargetService.set_bullet_parent(_world)

  _boss = BOSS.instantiate()
  _world.add_child(_boss)
  _boss.global_position = Vector2(448, 200)
  _ai = _boss.get_node("EnemyAI")
  _hp = _boss.get_node("HpNode")


func _start_phase(phase_idx: int) -> void:
  _ai._phase_idx = phase_idx - 1
  _ai._next_phase()


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  TargetService.set_bullet_parent(null)
  get_tree().current_scene = _saved_scene
  _world.free()


func _aimed_patterns() -> Array:
  var result := []
  for core in _ai._pattern_cores:
    if core.attack_pattern.direction_type == AttackPattern.DirectionType.TO_PLAYER:
      result.append(core.attack_pattern)
  return result


func _ring_pattern() -> AttackPattern:
  for core in _ai._pattern_cores:
    if core.attack_pattern.direction_type == AttackPattern.DirectionType.CIRCLE:
      return core.attack_pattern
  return null


## HP を、3方向に切り替わる境目の1つ上まで減らす
func _damage_to_just_above_threshold() -> void:
  var threshold := floori(_hp.max_hp * _ai.phase5_spread_hp_ratio)
  _hp.take_damage(_hp.current_hp - (threshold + 1))


func test_phase5_starts_with_single_aimed_shots() -> void:
  _start_phase(5)
  assert_int(_ai._phase_idx).is_equal(5)
  assert_int(_aimed_patterns().size()).is_greater(0)
  for p in _aimed_patterns():
    assert_int(p.bullet_count).is_equal(1)


func test_stays_single_while_hp_above_ratio() -> void:
  _start_phase(5)
  _damage_to_just_above_threshold()

  assert_int(_ai._phase_idx).is_equal(5)
  for p in _aimed_patterns():
    assert_int(p.bullet_count).is_equal(1)


func test_switches_to_three_way_spread_at_ratio() -> void:
  _start_phase(5)
  var ring_count := _ring_pattern().bullet_count
  var aimed_cores := _aimed_patterns().size()
  _damage_to_just_above_threshold()

  _hp.take_damage(1)

  assert_int(_ai._phase_idx).is_equal(5)
  assert_int(_aimed_patterns().size()).is_equal(aimed_cores)
  for p in _aimed_patterns():
    assert_int(p.bullet_count).is_equal(3)
    assert_float(p.angle_spread).is_greater(0.0)
  assert_int(_ring_pattern().bullet_count).is_equal(ring_count)


## フェーズの各パターンを順に始め、突進のアニメーションと残像が出ているかを返す
func _rush_and_afterimage_per_pattern(phase_idx: int) -> Array:
  _start_phase(phase_idx)
  var sprite: AnimatedSprite2D = _boss.get_node("AnimatedSprite2D")
  var result := []
  for i in _ai.patterns.size():
    if i > 0:
      _ai._on_pattern_completed(_ai._token)  # 前のパターンが終わった（アニメーションを戻して次へ）
    result.append([sprite.animation == "rush", _ai._is_afterimage_enabled])
  return result


func test_afterimage_only_while_rushing_in_phase8_and_9() -> void:
  for phase_idx in [8, 9]:
    var states := _rush_and_afterimage_per_pattern(phase_idx)
    var rush_count := 0
    for state in states:
      # 突進のアニメーションのときだけ残像が出る
      assert_bool(state[1]).override_failure_message("phase %d: %s" % [phase_idx, states]).is_equal(
        state[0]
      )
      if state[0]:
        rush_count += 1
    assert_int(rush_count).is_greater(0)
