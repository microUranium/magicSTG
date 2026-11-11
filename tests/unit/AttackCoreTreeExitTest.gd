# === 発射中にコアがツリーから外れたときのテスト ===
# シーン切り替え（change_scene_to_file）では、古いシーンはすぐツリーから外れ、
# 解放されるのはフレームの終わりになる。その間にコアのタイマーが発火すると、
# get_tree() が null のまま create_timer() などを呼んでクラッシュしていた。
extends GdUnitTestSuite

var _scene: Node2D
var _owner_actor: Node2D
var _core: TestableUniversalAttackCore
var _bullet_scene: PackedScene


func before_test() -> void:
  _scene = Node2D.new()
  add_child(_scene)

  _owner_actor = Node2D.new()
  _scene.add_child(_owner_actor)

  var stub := BulletStub.new()
  _bullet_scene = PackedScene.new()
  _bullet_scene.pack(stub)
  stub.free()


func after_test() -> void:
  if is_instance_valid(_core):
    for b in _core.spawned_bullets:
      if is_instance_valid(b):
        b.free()
    if not _core.is_inside_tree():
      _core.free()
  _scene.free()


func _make_pattern(type: AttackPattern.PatternType) -> AttackPattern:
  var pattern := AttackPattern.new()
  pattern.pattern_type = type
  pattern.bullet_count = 1
  pattern.auto_start = false  # クールダウンタイマーの自動開始を止め、trigger() だけを検証する
  pattern.bullet_scene = _bullet_scene
  pattern.beam_scene = _bullet_scene
  return pattern


func _add_core(pattern: AttackPattern) -> void:
  _core = TestableUniversalAttackCore.new()
  _core.attack_pattern = pattern
  _scene.add_child(_core)
  _core.set_owner_actor(_owner_actor)


func _assert_stopped_cleanly() -> void:
  assert_bool(_core._firing).is_false()
  assert_bool(_core._cooling).is_false()
  assert_object(_core._cool_timer).is_null()


func test_trigger_does_not_crash_when_removed_from_tree_mid_rapid_fire() -> void:
  var pattern := _make_pattern(AttackPattern.PatternType.RAPID_FIRE)
  pattern.rapid_fire_count = 3
  pattern.rapid_fire_interval = 0.2
  _add_core(pattern)

  _core.trigger()  # 1発目を撃ち、連射間隔のタイマー待ちに入る
  await await_millis(50)

  # シーン切り替え直後と同じ「ツリー外だが未解放」の状態を作る
  _scene.remove_child(_core)

  # 連射間隔のタイマーが発火して連射コルーチンが再開するまで待つ
  await await_millis(300)

  _assert_stopped_cleanly()
  # タイマー発火後の2発目は撃つが、次の間隔待ちの前で打ち切り、3発目を一気に撃たない
  assert_int(_core.get_spawned_bullet_count()).is_equal(2)


func test_beam_with_warning_does_not_fire_when_removed_from_tree_during_warning() -> void:
  var pattern := _make_pattern(AttackPattern.PatternType.BEAM)
  var warning := AttackWarningConfig.new()
  warning.warning_duration = 0.2
  pattern.warning_configs = [warning]
  _add_core(pattern)

  _core.trigger()  # 警告線を出して待ちに入る
  await await_millis(50)
  _scene.remove_child(_core)

  # 警告のタイマーが発火するまで待つ
  await await_millis(300)

  _assert_stopped_cleanly()
  assert_int(_core.get_spawned_bullet_count()).is_equal(0)


func test_composite_does_not_run_next_layer_when_removed_from_tree_during_delay() -> void:
  var first := _make_pattern(AttackPattern.PatternType.SINGLE_SHOT)
  var beam := _make_pattern(AttackPattern.PatternType.BEAM)
  var composite := _make_pattern(AttackPattern.PatternType.SINGLE_SHOT)
  composite.pattern_layers = [first, beam]
  composite.layer_delays = [0.0, 0.2]
  _add_core(composite)

  _core.trigger()  # 1レイヤー目を撃ち、2レイヤー目の遅延待ちに入る
  await await_millis(50)
  _scene.remove_child(_core)

  await await_millis(300)

  _assert_stopped_cleanly()
  assert_int(_core.get_spawned_bullet_count()).is_equal(1)


func test_start_cooldown_is_noop_outside_tree() -> void:
  _add_core(_make_pattern(AttackPattern.PatternType.SINGLE_SHOT))
  _scene.remove_child(_core)

  _core._start_cooldown()

  assert_bool(_core._cooling).is_false()
  assert_object(_core._cool_timer).is_null()


func test_on_cooldown_finished_is_noop_outside_tree() -> void:
  _add_core(_make_pattern(AttackPattern.PatternType.SINGLE_SHOT))
  _scene.remove_child(_core)

  _core._on_cooldown_finished()

  assert_object(_core._cool_timer).is_null()
  assert_int(_core.get_spawned_bullet_count()).is_equal(0)
