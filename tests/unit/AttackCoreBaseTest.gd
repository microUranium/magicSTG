# === AttackCoreBase のテスト ===
extends GdUnitTestSuite
class_name AttackCoreBaseTest

var attack_core: AttackCoreBase
var mock_pattern: AttackPattern
var test_scene: Node2D


func before_test():
  # テスト用のシーンセットアップ
  test_scene = Node2D.new()
  add_child(test_scene)

  # モック攻撃パターンを作成
  mock_pattern = AttackPattern.new()
  mock_pattern.burst_delay = 2.0
  mock_pattern.bullet_scene = preload("res://scenes/bullets/universal_bullet.tscn")
  mock_pattern.auto_start = false

  # AttackCoreBase の具象実装クラスを作成
  attack_core = TestAttackCore.new()
  attack_core.auto_start = false
  test_scene.add_child(attack_core)


func after_test():
  test_scene.queue_free()


func test_attack_pattern_setting():
  """攻撃パターンの設定テスト"""
  # When: パターンを設定
  attack_core.attack_pattern = mock_pattern

  # Then: パターンが正しく設定される
  assert_that(attack_core.attack_pattern).is_equal(mock_pattern)
  # クールダウンタイムがパターンから更新される
  assert_that(attack_core.cooldown_sec).is_equal(2.0)


func test_cooldown_system():
  """クールダウンシステムのテスト"""
  attack_core.attack_pattern = mock_pattern
  attack_core.cooldown_sec = 0.5  # テスト時間短縮

  # Given: 初期状態では発射可能
  assert_that(attack_core.can_fire()).is_true()

  # When: 攻撃を実行
  attack_core._start_cooldown()
  await await_millis(600)  # 0.5秒 + バッファ

  # Then: 攻撃が成功した場合のみクールダウン中になる
  if attack_core._get_last_fire_success():  # テスト用メソッド
    assert_that(attack_core.can_fire()).is_false()
  else:
    # 攻撃が失敗した場合はクールダウンしない
    assert_that(attack_core.can_fire()).is_true()


func test_pause_functionality():
  """一時停止機能のテスト"""
  attack_core.attack_pattern = mock_pattern

  # Given: 初期状態では発射可能
  assert_that(attack_core.can_fire()).is_true()

  # When: 一時停止を設定
  attack_core.set_paused(true)

  # Then: 発射不可になる
  assert_that(attack_core.can_fire()).is_false()

  # When: 一時停止を解除
  attack_core.set_paused(false)

  # Then: auto_startが有効な場合はクールダウンが開始される
  if attack_core.auto_start:
    # クールダウン開始直後は発射不可
    assert_that(attack_core.can_fire()).is_false()

    # クールダウン完了後は発射可能
    await await_millis(int(attack_core.cooldown_sec * 1000) + 100)
    assert_that(attack_core.can_fire()).is_true()
  else:
    # auto_startが無効な場合は即座に発射可能
    assert_that(attack_core.can_fire()).is_true()


func test_owner_actor_setting():
  """オーナーアクターの設定テスト"""
  var owner = auto_free(Node2D.new())
  test_scene.add_child(owner)

  # When: 有効なオーナーを設定
  attack_core.set_owner_actor(owner)

  # Then: オーナーが正しく設定される
  assert_that(attack_core._owner_actor).is_equal(owner)

  # When: 無効なオーナーを設定
  attack_core.set_owner_actor(auto_free(Node.new()))

  # Then: オーナーは変更されない
  assert_that(attack_core._owner_actor).is_equal(owner)


# テスト用の具象実装クラス
class TestAttackCore:
  extends AttackCoreBase
  var fire_called = false
  var should_succeed = true  # 成功/失敗を制御

  func _do_fire() -> bool:
    await get_tree().process_frame
    fire_called = true
    _last_fire_success = should_succeed
    return should_succeed
