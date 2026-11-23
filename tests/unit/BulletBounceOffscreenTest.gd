# === 跳ね返る弾が壁際で消えないことのテスト（ProjectileBullet / UniversalBullet） ===
# 以前は「移動 → 画面外なら即座に消す → 跳ね返り判定」の順だったため、1フレームの移動量が
# 壁際の判定幅（4px）より大きいと、跳ね返る前に画面外として消えることがあった（熊の鎌など）。
# テスト対象:
#   1. 跳ね返りの回数が残っていれば、速く真っすぐ壁に当たっても必ず跳ね返る
#   2. 跳ね返りを使い切った後は、画面外に出た時点で消える
#   3. 跳ね返らない弾は、これまでどおり画面外に出た時点で消える
extends GdUnitTestSuite

const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 896)
const BULLET := preload("res://scenes/bullets/universal_bullet.tscn")
const SCYTHE := preload("res://scenes/bullets/scythe_bullet.tscn")
const STEP := 1.0 / 60.0

var _saved_rect: Rect2
var _world: Node2D


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _world = Node2D.new()
  add_child(_world)


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  _world.free()


func _movement(speed: float, bounce_factor: float, max_bounces: int) -> BulletMovementConfig:
  var m := BulletMovementConfig.new()
  m.movement_type = BulletMovementConfig.MovementType.STRAIGHT
  m.initial_speed = speed
  m.bounce_factor = bounce_factor
  m.max_bounces = max_bounces
  return m


## 下の壁から gap px 手前で、真下へ撃つ（_process は止め、1フレームずつ手動で進める）
func _spawn(scene: PackedScene, movement: BulletMovementConfig, gap: float) -> UniversalBullet:
  var b: UniversalBullet = scene.instantiate()
  _world.add_child(b)
  b.set_process(false)
  b.global_position = Vector2(448, PLAY_RECT.end.y - gap)
  b.direction = Vector2.DOWN
  b.apply_movement_config(movement)
  return b


## 消えるか跳ね返るまで進める。"lost" / "bounce" / "none"
func _run_until_wall(b: UniversalBullet, frames := 120) -> String:
  for i in frames:
    b._bullet_process(STEP)
    if b.is_queued_for_deletion():
      return "lost"
    if b._bounce_count > 0:
      return "bounce"
  return "none"


func test_fast_bullet_always_bounces_at_wall() -> void:
  # 1フレーム 700/60 ≒ 11.7px 進む。壁までの距離を 0.1px 刻みで1フレーム分ずらしても、必ず跳ね返る
  for gap_tenths in range(100, 220):
    var b := _spawn(BULLET, _movement(700.0, 1.0, 1), gap_tenths / 10.0)
    var result := _run_until_wall(b)
    assert_str(result).override_failure_message("gap=%.1f" % (gap_tenths / 10.0)).is_equal("bounce")
    # 壁の内側に戻され、上向きに反射している
    assert_bool(PLAY_RECT.has_point(b.global_position)).is_true()
    assert_float(b.direction.y).is_less(0.0)
    b.free()


func test_scythe_bounces_regardless_of_rotation() -> void:
  # 熊の鎌（自転する）でも、自転の角度に関係なく跳ね返る
  for rot in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
    var m := _movement(700.0, 1.0, 5)
    m.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
    m.angular_velocity = 360
    var b := _spawn(SCYTHE, m, 15.0)
    b.rotation = deg_to_rad(rot)
    assert_str(_run_until_wall(b)).is_equal("bounce")
    b.free()


func test_bullet_removed_offscreen_after_bounces_used_up() -> void:
  # 1回跳ね返った後、上の壁から外へ出たところで消える（跳ね返りの回数が残っていないので）
  var b := _spawn(BULLET, _movement(700.0, 1.0, 1), 15.0)
  assert_str(_run_until_wall(b)).is_equal("bounce")

  var lost := false
  for i in 200:  # 画面の高さ 896px を 11.7px/フレームで抜けるのに約77フレーム
    b._bullet_process(STEP)
    if b.is_queued_for_deletion():
      lost = true
      break
  assert_bool(lost).is_true()
  assert_int(b._bounce_count).is_equal(1)
  b.free()


func test_non_bouncing_bullet_removed_offscreen() -> void:
  var b := _spawn(BULLET, _movement(700.0, 0.0, 0), 15.0)
  assert_str(_run_until_wall(b)).is_equal("lost")
  b.free()
