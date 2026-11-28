# === harpy のフェーズ3の動きと攻撃の切り替えのテスト ===
# フェーズ3は「左右に移動して止まる」を繰り返したあと、中央へ移動 → 中央で止まる → 中央へ戻る。
# テスト対象:
#   1. 左右に移動・停止している間は通常の攻撃（phase3_patterns_1）
#   2. 中央へ移動し始めてから中央で止まっている間は、高密度のバリア弾（phase3_patterns_2）
#   3. 中央へ戻り始めたら通常の攻撃に戻る
#   4. 左右の移動のあとには、必ず止まるパターンがある
#   5. フェーズ3の自機狙い弾は、フェーズ1より方向数が多く・扇が広く・間隔が短い（弾速の組み合わせは同じ）
# パターンの数は調整で変わるため、末尾の中央のパターンの位置はパターン数から求める
extends GdUnitTestSuite

const HARPY := preload("res://scenes/enemy/harpy.tscn")
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 960)

var _saved_rect: Rect2
var _world: Node2D
var _harpy: Node2D
var _ai: HarpyAI


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _world = Node2D.new()
  add_child(_world)
  TargetService.set_bullet_parent(_world)
  _harpy = HARPY.instantiate()
  _world.add_child(_harpy)
  _harpy.global_position = Vector2(448, 144)
  _ai = _harpy.get_node("EnemyAI")
  # フェーズ3を始める
  _ai._phase_idx = 2
  _ai._next_phase()


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  TargetService.set_bullet_parent(null)
  _world.free()


func _is_dense_attack() -> bool:
  return (
    _ai._pattern_cores.size() == _ai.phase3_patterns_2.size()
    and _ai._pattern_cores[0].attack_pattern == _ai.phase3_patterns_2[0]
  )


func test_dense_barrier_only_while_moving_to_and_staying_at_center() -> void:
  assert_int(_ai._phase_idx).is_equal(3)
  var n: int = _ai.patterns.size()
  # 末尾3つ（中央へ移動・中央で停止・中央へ戻る）のうち、最初の2つの間だけ高密度
  for i in n:
    if i > 0:
      _ai._on_pattern_completed(_ai._token)
    var expect_dense := i == n - 3 or i == n - 2
    assert_bool(_is_dense_attack()).override_failure_message("pattern %d" % i).is_equal(
      expect_dense
    )
  # 一周して最初の移動に戻っても通常の攻撃
  _ai._on_pattern_completed(_ai._token)
  assert_bool(_is_dense_attack()).is_false()


func test_each_side_move_is_followed_by_stay() -> void:
  var patterns: Array = _ai.patterns
  var n := patterns.size()
  for i in range(0, n - 3):
    var p: EnemyPatternResource = patterns[i]
    if p.movement_type == EnemyPatternResource.MovementType.MOVE_TO_POSITION:
      var next: EnemyPatternResource = patterns[i + 1]
      assert_int(next.movement_type).is_equal(EnemyPatternResource.MovementType.STAY_IN_PLACE)


func _aimed(patterns: Array) -> Array:
  return patterns.filter(
    func(p):
      return (
        p.pattern_type == AttackPattern.PatternType.RAPID_FIRE
        and p.direction_type == AttackPattern.DirectionType.TO_PLAYER
      )
  )


func test_phase3_aimed_is_denser_than_phase1() -> void:
  var p1 := _aimed(_ai.phase1_patterns)
  var p3 := _aimed(_ai.phase3_patterns_1)
  assert_int(p3.size()).is_equal(p1.size())
  for i in p3.size():
    assert_int(p3[i].bullet_count).is_greater(p1[i].bullet_count)
    assert_float(p3[i].angle_spread).is_greater(p1[i].angle_spread)
    assert_float(p3[i].burst_delay).is_less(p1[i].burst_delay)
    assert_float(p3[i].bullet_movement_config.initial_speed).is_equal(
      p1[i].bullet_movement_config.initial_speed
    )
  # フェーズ3の通常の攻撃で、実際にフェーズ3の自機狙い弾を撃つ
  var firing := _ai._pattern_cores.map(func(c): return c.attack_pattern)
  for p in p3:
    assert_bool(firing.has(p)).is_true()
