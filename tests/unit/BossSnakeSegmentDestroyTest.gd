# === boss_snake の節が壊れたときの攻撃のテスト ===
# 節が壊れると、その節から弾を撒く（BossSnakeBodyAI.fire_destroy_attack）。
# 以前は節の tree_exiting で撃っていたが、そのときにはコアがツリーから外れていて弾が出なかった
# テスト対象:
#   1. 節を壊すと、その節から弾が出る
#   2. 壊した節は消える
#   3. 画面外で壊れた節（尾）の弾も、画面外に出たことで消えない
extends GdUnitTestSuite

const BOSS_SNAKE := preload("res://scenes/enemy/enemy_boss_snake.tscn")
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 960)

var _saved_rect: Rect2
var _saved_scene: Node
var _saved_player: Node2D
var _world: Node2D
var _bullets: Node2D
var _boss: Node2D


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _saved_scene = get_tree().current_scene
  # 節の管理ノードは current_scene に追加されるため、テスト用の world を current_scene にする
  _world = Node2D.new()
  get_tree().root.add_child(_world)
  get_tree().current_scene = _world
  _bullets = Node2D.new()
  _world.add_child(_bullets)
  TargetService.set_bullet_parent(_bullets)
  _saved_player = TargetService.get_player()
  var player := Node2D.new()
  _world.add_child(player)
  player.global_position = Vector2(448, 800)
  TargetService.register_player(player)

  _boss = BOSS_SNAKE.instantiate()
  _world.add_child(_boss)
  _boss.global_position = Vector2(448, 200)
  _boss.setup()  # 節を作る（本来はフェーズ1の開始時に呼ばれる）
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


func test_destroying_segment_fires_bullets() -> void:
  var manager = _boss.segment_manager
  var count_before: int = manager.get_segment_count()
  assert_int(count_before).is_greater(0)
  var last = manager.get_all_segments()[-1]
  # 作った直後の節は画面外にあり、出た弾がすぐ消えるので、画面内へ動かしてから壊す
  last.global_position = PLAY_RECT.get_center()
  var bullets_before := _bullets.get_child_count()

  _boss._destroy_segment()

  assert_int(_bullets.get_child_count()).is_greater(bullets_before)
  await await_idle_frame()
  assert_int(_bullets.get_child_count()).is_greater(bullets_before)  # 節が消えても弾は残る
  assert_int(manager.get_segment_count()).is_equal(count_before - 1)
  assert_bool(is_instance_valid(last)).is_false()


func test_bullets_from_offscreen_segment_are_kept() -> void:
  var manager = _boss.segment_manager
  var last = manager.get_all_segments()[-1]
  last.global_position = Vector2(-300, PLAY_RECT.get_center().y)  # 画面外
  # 壊れたときに撒く弾の数（同時に出る自機狙い弾は画面外で消えてよいので数えない）
  var destroy_pattern: AttackPattern = last.get_node("EnemyAI").phase1_patterns.filter(func(p): return not p.auto_start)[0]
  assert_bool(destroy_pattern.persist_offscreen).is_true()
  var bullets_before := _bullets.get_child_count()

  _boss._destroy_segment()

  for i in 5:
    await await_idle_frame()
  # 画面外に出ても消えない（弾の一斉消去や寿命までは残る）
  assert_int(_bullets.get_child_count() - bullets_before).is_greater_equal(
    destroy_pattern.bullet_count
  )
