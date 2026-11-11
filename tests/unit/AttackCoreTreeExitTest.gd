# === 発射中にコアがツリーから外れたときのテスト ===
# シーン切り替え（change_scene_to_file）では、古いシーンはすぐツリーから外れ、
# 解放されるのはフレームの終わりになる。その間に連射のタイマーが発火すると、
# get_tree() が null のまま _start_cooldown() が呼ばれてクラッシュしていた。
extends GdUnitTestSuite

var _scene: Node2D
var _owner_actor: Node2D
var _core: TestableUniversalAttackCore
var _pattern: AttackPattern


func before_test() -> void:
  _scene = Node2D.new()
  add_child(_scene)

  _owner_actor = Node2D.new()
  _scene.add_child(_owner_actor)

  _pattern = AttackPattern.new()
  _pattern.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  _pattern.bullet_count = 1
  _pattern.rapid_fire_count = 3
  _pattern.rapid_fire_interval = 0.05
  _pattern.auto_start = false  # クールダウンタイマーの自動開始を止め、trigger() だけを検証する
  var bullet_scene := PackedScene.new()
  bullet_scene.pack(BulletStub.new())
  _pattern.bullet_scene = bullet_scene

  _core = TestableUniversalAttackCore.new()
  _core.attack_pattern = _pattern
  _scene.add_child(_core)
  _core.set_owner_actor(_owner_actor)


func after_test() -> void:
  for b in _core.spawned_bullets:
    if is_instance_valid(b):
      b.free()
  if is_instance_valid(_core) and not _core.is_inside_tree():
    _core.free()
  _scene.free()


func test_trigger_does_not_crash_when_removed_from_tree_mid_rapid_fire() -> void:
  _core.trigger()  # 1発目を撃ち、連射間隔のタイマー待ちに入る
  await await_millis(20)

  # シーン切り替え直後と同じ「ツリー外だが未解放」の状態を作る
  _scene.remove_child(_core)

  # 連射間隔のタイマーが発火して連射コルーチンが再開するまで待つ
  await await_millis(150)

  assert_bool(_core._firing).is_false()
  assert_bool(_core._cooling).is_false()
  assert_object(_core._cool_timer).is_null()
  # タイマー発火後の2発目は撃つが、次の間隔待ちの前で打ち切り、3発目を一気に撃たない
  assert_int(_core.get_spawned_bullet_count()).is_equal(2)


func test_start_cooldown_is_noop_outside_tree() -> void:
  _scene.remove_child(_core)

  _core._start_cooldown()

  assert_bool(_core._cooling).is_false()
  assert_object(_core._cool_timer).is_null()
