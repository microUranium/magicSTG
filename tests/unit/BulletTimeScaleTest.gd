# === 弾の時間の進み方（time_scale）のテスト ===
# 時界の加護の結界内では敵弾の time_scale が 0.05 になる。
# テスト対象:
#   1. 直進弾は time_scale 0.05 で 1/20 しか進まない
#   2. 動き方（重力など）にかかわらず「time_scale × delta で進めた場合」と同じ結果になる
#   3. 寿命も弾の時間で進む
#   4. time_scale 1.0（既定）では従来どおり
#   5. vanish() で消える（爆発させない消し方。爆発の有無は時界の加護のテストで確認）
extends GdUnitTestSuite

const BULLET_SCENE := "res://scenes/bullets/universal_bullet.tscn"
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")

var _saved_rect: Rect2


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = Rect2(-5000, -5000, 10000, 10000)  # 画面外で消えないように


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect


func _make_bullet(cfg: BulletMovementConfig = null, spd := 100.0) -> Node2D:
  var bullet: Node2D = auto_free(load(BULLET_SCENE).instantiate())
  bullet.movement_config = null
  bullet.direction = Vector2.UP
  bullet.speed = spd
  bullet.min_speed = spd  # 減速 Tween を走らせない
  add_child(bullet)
  bullet.set_process(false)  # フレームはテストから手動で進める
  bullet.global_position = Vector2.ZERO
  if cfg:
    bullet.apply_movement_config(cfg)
  return bullet


func test_straight_bullet_moves_one_twentieth() -> void:
  var normal := _make_bullet()
  var slowed := _make_bullet()
  slowed.set_time_scale(0.05)

  normal._process(1.0)
  slowed._process(1.0)

  assert_float(normal.global_position.distance_to(Vector2.ZERO)).is_equal_approx(100.0, 0.01)
  assert_float(slowed.global_position.distance_to(Vector2.ZERO)).is_equal_approx(5.0, 0.01)


func test_gravity_bullet_matches_scaled_delta() -> void:
  """重力のように速度が変わる動きでも、time_scale 0.05 で dt 進める ＝ time_scale 1.0 で dt×0.05 進める"""
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = BulletMovementConfig.MovementType.GRAVITY
  cfg.initial_speed = 500.0
  var slowed := _make_bullet(cfg)
  var reference := _make_bullet(cfg)
  slowed.set_time_scale(0.05)

  for _i in 10:
    slowed._process(1.0 / 6.0)
    reference._process(1.0 / 6.0 * 0.05)

  assert_vector(slowed.global_position).is_equal_approx(
    reference.global_position, Vector2(0.01, 0.01)
  )


func test_lifetime_follows_bullet_time() -> void:
  var slowed := _make_bullet()
  slowed.bullet_lifetime = 1.0
  slowed.set_time_scale(0.05)

  slowed._process(2.0)  # 弾の時間では 0.1 秒

  assert_bool(slowed.is_queued_for_deletion()).is_false()
  assert_float(slowed._lifetime_timer).is_equal_approx(0.1, 0.0001)


func test_default_time_scale_is_unchanged() -> void:
  var bullet := _make_bullet()
  assert_float(bullet.time_scale).is_equal_approx(1.0, 0.0001)

  bullet._process(0.5)

  assert_float(bullet.global_position.distance_to(Vector2.ZERO)).is_equal_approx(50.0, 0.01)


func test_vanish_removes_bullet() -> void:
  var bullet := _make_bullet()

  bullet.vanish()

  assert_bool(bullet.is_queued_for_deletion()).is_true()
