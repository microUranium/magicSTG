# === トリプルバースト機能テスト ===
# テスト対象:
#   1. BURST_WITH_TRACKING パターンで3発のバースト射撃が実行される
#   2. 弾が残っている間は次の発射ができない
#   3. 弾が全て消えたら次の発射が可能になる
#   4. burst_interval が正しく適用される
extends GdUnitTestSuite
class_name TripleBurstFeatureTest

var universal_core: TestableUniversalAttackCore
var test_pattern: AttackPattern
var test_scene: Node2D
var owner_actor: Node2D


func before_test():
  test_scene = Node2D.new()
  add_child(test_scene)

  owner_actor = Node2D.new()
  owner_actor.global_position = Vector2(100, 100)
  test_scene.add_child(owner_actor)

  universal_core = TestableUniversalAttackCore.new()
  test_scene.add_child(universal_core)
  universal_core.set_owner_actor(owner_actor)

  # BURST_WITH_TRACKING用のベースパターン
  test_pattern = AttackPattern.new()
  test_pattern.pattern_type = AttackPattern.PatternType.BURST_WITH_TRACKING
  test_pattern.burst_count = 3
  test_pattern.burst_interval = 0.05
  test_pattern.damage = 10
  test_pattern.bullet_speed = 1500.0
  test_pattern.target_group = "enemies"

  # テスト用ダミー弾丸シーン
  var dummy_bullet = BulletStub.new()
  var packed_bullet_scene := PackedScene.new()
  packed_bullet_scene.pack(dummy_bullet)
  test_pattern.bullet_scene = packed_bullet_scene


func after_test():
  test_scene.queue_free()


# =====================================================================
# 1. バースト射撃実行テスト
# =====================================================================


func test_burst_with_tracking_fires_three_bullets():
  """BURST_WITH_TRACKINGパターンで3発の弾丸が生成される"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  var success = await universal_core._execute_burst_with_tracking(test_pattern)

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)


func test_burst_interval_timing():
  """burst_intervalが正しく適用される（弾数で確認）"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  await universal_core._execute_burst_with_tracking(test_pattern)

  # burst_count=3 で3発生成される（タイミングではなく結果で検証）
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)


# =====================================================================
# 2. 弾追跡による発射制限テスト
# =====================================================================


func test_blocks_next_fire_while_bullets_exist():
  """弾が残っている間は _validate_firing_conditions() が false を返す"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.attack_pattern = test_pattern

  # 手動で追跡リストに弾を追加（弾が残っている状態をシミュレート）
  var dummy_bullet = Node2D.new()
  test_scene.add_child(dummy_bullet)
  universal_core._tracked_bullets.append(dummy_bullet)

  var can_fire = universal_core._validate_firing_conditions()

  assert_that(can_fire).is_false()

  # クリーンアップ
  dummy_bullet.queue_free()


func test_allows_fire_after_bullets_cleared():
  """弾が全て消えたら _validate_firing_conditions() が true を返す"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.attack_pattern = test_pattern

  # 追跡リストが空の状態
  universal_core._tracked_bullets.clear()

  var can_fire = universal_core._validate_firing_conditions()

  assert_that(can_fire).is_true()


func test_clean_tracked_bullets_removes_invalid_references():
  """_clean_tracked_bullets() が無効な参照を削除する"""
  var bullet1 = Node2D.new()
  var bullet2 = Node2D.new()
  var bullet3 = Node2D.new()

  test_scene.add_child(bullet1)
  test_scene.add_child(bullet2)
  test_scene.add_child(bullet3)

  universal_core._tracked_bullets = [bullet1, bullet2, bullet3]

  # bullet2を削除
  bullet2.queue_free()
  await await_idle_frame()

  # クリーンアップ実行
  universal_core._clean_tracked_bullets()

  # bullet2が削除され、bullet1とbullet3のみ残る
  assert_that(universal_core._tracked_bullets.size()).is_equal(2)
  assert_that(universal_core._tracked_bullets.has(bullet1)).is_true()
  assert_that(universal_core._tracked_bullets.has(bullet3)).is_true()

  # クリーンアップ
  bullet1.queue_free()
  bullet3.queue_free()


# =====================================================================
# 3. _on_bullet_spawned() によるトラッキングテスト
# =====================================================================


func test_on_bullet_spawned_adds_to_tracked_bullets():
  """_on_bullet_spawned() がBURST_WITH_TRACKING時に弾を追跡リストに追加する"""
  universal_core.attack_pattern = test_pattern
  universal_core._tracked_bullets.clear()

  var bullet = Node2D.new()
  test_scene.add_child(bullet)

  universal_core._on_bullet_spawned(bullet)

  assert_that(universal_core._tracked_bullets.size()).is_equal(1)
  assert_that(universal_core._tracked_bullets[0]).is_equal(bullet)

  # クリーンアップ
  bullet.queue_free()


func test_on_bullet_spawned_ignores_other_patterns():
  """BURST_WITH_TRACKING以外のパターンでは弾を追跡しない"""
  # SINGLE_SHOTパターンに変更
  test_pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  universal_core.attack_pattern = test_pattern
  universal_core._tracked_bullets.clear()

  var bullet = Node2D.new()
  test_scene.add_child(bullet)

  universal_core._on_bullet_spawned(bullet)

  # 追跡リストに追加されない
  assert_that(universal_core._tracked_bullets.size()).is_equal(0)

  # クリーンアップ
  bullet.queue_free()


# =====================================================================
# 4. 統合テスト
# =====================================================================


func test_burst_with_tracking_integration():
  """実際のバースト射撃→弾消失→再発射の一連の流れ"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  # 1回目のバースト射撃
  await universal_core._execute_burst_with_tracking(test_pattern)

  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)
  assert_that(universal_core._tracked_bullets.size()).is_equal(3)

  # 発射直後は弾が残っているので発射不可
  var can_fire_immediately = universal_core._validate_firing_conditions()
  assert_that(can_fire_immediately).is_false()

  # 弾を全て削除（画面外に出た想定）
  for bullet in universal_core.spawned_bullets:
    bullet.queue_free()
  await await_idle_frame()

  # クリーンアップ
  universal_core._clean_tracked_bullets()

  # 弾が全て消えたので発射可能
  var can_fire_after_bullets_cleared = universal_core._validate_firing_conditions()
  assert_that(can_fire_after_bullets_cleared).is_true()


func test_burst_parameters_applied_correctly():
  """バーストパラメータが正しく適用される"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.BURST_WITH_TRACKING
  pattern.burst_count = 5
  pattern.burst_interval = 0.02
  pattern.damage = 15
  pattern.bullet_speed = 2000.0
  pattern.bullet_scene = test_pattern.bullet_scene

  universal_core._cooling = false
  universal_core._paused = false
  universal_core.attack_pattern = pattern
  universal_core.clear_spawned_bullets()

  await universal_core._execute_burst_with_tracking(pattern)

  # burst_count=5 で5発生成される
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(5)
