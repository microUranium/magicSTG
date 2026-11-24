# === 加護の影響を受けない弾（immune_to_blessings）のテスト ===
# テスト対象:
#   1. immune_to_blessings の敵弾は、打消の加護の弾消し（destroy_bullets_by_target）で消えない
#   2. ステージ側の一斉消去（destroy_bullet）では、これまでどおり消える
#   3. 通常の敵弾は打消の加護で消える
#   4. AttackPattern.immune_to_blessings がコアから撃った弾に引き継がれる
# 時界の加護については SpacetimeBlessingTest で確認する
extends GdUnitTestSuite


class StubBullet:
  extends BulletBase


func _make_bullet(immune: bool) -> StubBullet:
  var bullet := StubBullet.new()
  bullet.target_group = "players"
  bullet.immune_to_blessings = immune
  add_child(bullet)
  auto_free(bullet)
  return bullet


func test_immune_bullet_survives_nullify() -> void:
  var immune := _make_bullet(true)
  var normal := _make_bullet(false)

  StageSignals.emit_destroy_bullets_by_target("players")

  assert_bool(immune.is_queued_for_deletion()).is_false()
  assert_bool(normal.is_queued_for_deletion()).is_true()


func test_immune_bullet_still_removed_by_stage_clear() -> void:
  var immune := _make_bullet(true)

  StageSignals.emit_destroy_bullet()

  assert_bool(immune.is_queued_for_deletion()).is_true()


func test_pattern_flag_is_applied_to_spawned_bullet() -> void:
  var core: UniversalAttackCore = auto_free(UniversalAttackCore.new())
  var pattern := AttackPattern.new()
  pattern.immune_to_blessings = true
  var bullet := _make_bullet(false)

  core._apply_bullet_configs(bullet, pattern)

  assert_bool(bullet.immune_to_blessings).is_true()
