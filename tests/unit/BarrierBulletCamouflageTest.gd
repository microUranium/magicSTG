# === バリア弾の照準テスト（迷彩の加護との関係） ===
# バリア弾は軌道回転後、TO_TARGET なら保持しているターゲットノードへ向けて直進する。
# 迷彩中は本体ではなく囮座標へ向かわなければならない（ハーピー第二形態のバリア弾で発覚した不具合の回帰テスト）。
class_name BarrierBulletCamouflageTest
extends GdUnitTestSuite

const BARRIER_BULLET_SCENE := "res://scenes/bullets/enhanced_barrier_bullet.tscn"
const PLAY_AREA := preload("res://scripts/autoload/PlayArea.gd")
const DECOY := Vector2(100, 200)

var _saved_rect: Rect2
var _scene: Node2D
var _player: Node2D
var _enemy: Node2D


func before_test() -> void:
  _saved_rect = PLAY_AREA._play_rect
  PLAY_AREA._play_rect = Rect2(0, 0, 896, 960)

  _scene = auto_free(Node2D.new())
  add_child(_scene)

  _player = auto_free(Node2D.new())
  _player.add_to_group("players")
  _scene.add_child(_player)
  _player.global_position = Vector2(700, 800)
  TargetService.register_player(_player)

  _enemy = auto_free(Node2D.new())
  _scene.add_child(_enemy)
  _enemy.global_position = Vector2(400, 150)


func after_test() -> void:
  PLAY_AREA._play_rect = _saved_rect
  TargetService.unregister_player()


func _make_barrier_bullet() -> Node2D:
  var bullet: Node2D = auto_free(load(BARRIER_BULLET_SCENE).instantiate())
  var config := BarrierBulletMovement.new()
  config.projectile_direction_type = BarrierBulletMovement.ProjectileDirection.TO_TARGET
  bullet.movement_config = config
  _scene.add_child(bullet)
  bullet.setup_barrier_bullet(_enemy, "barrier_test", 1, 0, _player, 100.0, 5, "players")
  bullet.global_position = Vector2(400, 250)
  return bullet


func test_aims_at_player_when_visible() -> void:
  var bullet := _make_barrier_bullet()

  bullet._transition_to_projectile()

  var expected := (_player.global_position - bullet.global_position).normalized()
  assert_vector(bullet.direction).is_equal_approx(expected, Vector2(0.001, 0.001))


func test_aims_at_decoy_while_camouflaged() -> void:
  var bullet := _make_barrier_bullet()
  TargetService.set_player_targetable(false, DECOY)

  bullet._transition_to_projectile()

  var expected := (DECOY - bullet.global_position).normalized()
  assert_vector(bullet.direction).is_equal_approx(expected, Vector2(0.001, 0.001))
  TargetService.set_player_targetable(true)


func test_falls_back_when_target_lost() -> void:
  var bullet := _make_barrier_bullet()
  bullet.target_node = null

  bullet._transition_to_projectile()

  assert_vector(bullet.direction).is_equal(Vector2.DOWN)
