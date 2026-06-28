# === ボスHPバー（フェーズ単位リセット）テスト ===
extends GdUnitTestSuite

const BossHpBarScene = preload("res://scenes/ui/boss_hp_bar.tscn")

const FILL_WAIT_MS := 700  # 充填アニメ(0.5s)完了を待つ余裕


func _make_bar() -> Node2D:
  var bar := BossHpBarScene.instantiate()
  add_child(bar)
  return bar


func test_begin_phase_starts_from_zero() -> void:
  var bar := _make_bar()
  await await_idle_frame()

  bar.begin_phase(0, 100, 100)
  var prog := bar.get_node("ProgressBar") as TextureProgressBar
  # 充填はゼロ起点
  assert_float(prog.value).is_equal_approx(0.0, 0.01)

  bar.queue_free()


func test_begin_phase_fills_to_full() -> void:
  var bar := _make_bar()
  await await_idle_frame()

  bar.begin_phase(0, 100, 100)  # 現在HP=満タン
  await await_millis(FILL_WAIT_MS)

  var prog := bar.get_node("ProgressBar") as TextureProgressBar
  assert_float(prog.value).is_equal_approx(100.0, 0.5)

  bar.queue_free()


func test_update_hp_normalizes_segment() -> void:
  var bar := _make_bar()
  await await_idle_frame()

  # 区間 [200, 400]。充填完了を待ってから減少を反映。
  bar.begin_phase(200, 400, 400)
  await await_millis(FILL_WAIT_MS)

  bar.update_hp(300)  # 区間中央 → 50%
  var prog := bar.get_node("ProgressBar") as TextureProgressBar
  assert_float(prog.value).is_equal_approx(50.0, 0.01)

  bar.queue_free()


func test_update_hp_clamps_within_segment() -> void:
  var bar := _make_bar()
  await await_idle_frame()

  bar.begin_phase(200, 400, 400)
  await await_millis(FILL_WAIT_MS)
  var prog := bar.get_node("ProgressBar") as TextureProgressBar

  bar.update_hp(500)  # 上端超過 → 100%
  assert_float(prog.value).is_equal_approx(100.0, 0.01)

  bar.update_hp(100)  # 下端未満 → 0%
  assert_float(prog.value).is_equal_approx(0.0, 0.01)

  bar.queue_free()


func test_update_hp_ignored_during_fill() -> void:
  var bar := _make_bar()
  await await_idle_frame()

  bar.begin_phase(0, 100, 100)
  bar.update_hp(0)  # 充填中は無視される
  var prog := bar.get_node("ProgressBar") as TextureProgressBar
  assert_float(prog.value).is_equal_approx(0.0, 0.01)  # 0へ即落ちしない（充填継続中）

  bar.queue_free()


func test_hide_bar_makes_invisible() -> void:
  var bar := _make_bar()
  await await_idle_frame()

  bar.hide_bar()
  assert_bool(bar.visible).is_false()

  bar.queue_free()


func test_begin_phase_makes_visible() -> void:
  var bar := _make_bar()
  await await_idle_frame()

  bar.hide_bar()
  bar.begin_phase(0, 100, 100)
  assert_bool(bar.visible).is_true()

  bar.queue_free()
