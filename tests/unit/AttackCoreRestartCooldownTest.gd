# === AttackCoreBase.restart_cooldown のテスト ===
# 次に撃つまでの待ち時間だけを指定の秒数にし直し、その後の周期（cooldown_sec）は変えない
# あわせて get_cooldown_time_left（残りの待ち時間）も確認する
extends GdUnitTestSuite


func test_restart_cooldown_changes_only_next_wait() -> void:
  var core: UniversalAttackCore = auto_free(UniversalAttackCore.new())
  core.auto_start = false
  add_child(core)
  core.cooldown_sec = 5.0

  core.restart_cooldown(1.0)

  assert_bool(core._cooling).is_true()
  assert_float(core.get_cooldown_time_left()).is_equal_approx(1.0, 0.05)
  assert_float(core.cooldown_sec).is_equal(5.0)


func test_time_left_is_zero_when_not_cooling() -> void:
  var core: UniversalAttackCore = auto_free(UniversalAttackCore.new())
  core.auto_start = false
  add_child(core)

  assert_float(core.get_cooldown_time_left()).is_equal(0.0)
