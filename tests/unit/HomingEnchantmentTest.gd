# === 追尾エンチャント機能テスト ===
# テスト対象:
#   1. 既定値（追尾なし）では既存の弾の挙動が変わらないこと
#   2. 旋回半径 r = homing_distance^2 / (2 * homing_correction_px) の定義どおりに曲がること
#   3. 同じ設定なら弾速が違っても軌跡が一致すること（曲率ベース設計の核）
#   4. ロック条件（画面内 / 撃破処理中でない / 進行方向から一定角度以内 / 最も近い）
#   5. 追尾距離を飛び切ったら旋回をやめること
#   6. ターゲット消失時の再ロック、再ロック無効時は直進継続
#   7. SPIRAL / BOOMERANG では追尾を適用せず、GRAVITY では速度ベクトルを曲げること
#   8. エンチャントのティア値と、ファクトリー経由の反映（冪等性を含む）
extends GdUnitTestSuite
class_name HomingEnchantmentTest

const BULLET_SCENE := "res://scenes/bullets/universal_bullet.tscn"
const ENCHANT_PATH := "res://resources/data/enchantment_homing.tres"
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const DEAD_ENEMY_STUB := preload("res://tests/stubs/DeadEnemyStub.gd")

const PLAY_RECT := Rect2(0, 0, 896, 960)
const DISTANCE := 800.0  # 追尾が有効な飛行距離の既定値
const CORRECTION_L1 := 60.0
const CORRECTION_L2 := 150.0
const CORRECTION_L3 := 300.0

var _scene: Node2D
var _saved_play_rect: Rect2


func before_test() -> void:
  _scene = auto_free(Node2D.new())
  add_child(_scene)
  # 画面内判定を含むテストがあるため、プレイ領域を固定する
  _saved_play_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_play_rect


func _make_target(pos: Vector2, dead: bool = false) -> Area2D:
  var target: Area2D = DEAD_ENEMY_STUB.new() if dead else Area2D.new()
  target.add_to_group("enemies")
  _scene.add_child(target)
  auto_free(target)
  target.global_position = pos
  return target


func _make_bullet(
  pos: Vector2, dir: Vector2, spd: float, cfg: BulletMovementConfig = null
) -> Node2D:
  var bullet: Node2D = auto_free(load(BULLET_SCENE).instantiate())
  # シーン既定の movement_config は UniversalAttackCore と同様にクリアしておく
  bullet.movement_config = null
  bullet.direction = dir.normalized()
  bullet.speed = spd
  bullet.min_speed = spd  # _ready() の減速トゥイーンを走らせない
  _scene.add_child(bullet)
  bullet.set_process(false)  # フレームは手動で進める
  bullet.global_position = pos
  if cfg:
    bullet.apply_movement_config(cfg)
  return bullet


func _advance(bullet: Node2D, steps: int, dt: float) -> void:
  """ProjectileBullet._process() と同じ順序（移動 → 追尾補正）でフレームを進める"""
  for _i in steps:
    bullet.position += bullet.direction * bullet.speed * dt
    bullet._update_homing_overlay(dt)


func _advance_gravity(bullet: Node2D, steps: int, dt: float) -> void:
  for _i in steps:
    bullet._update_gravity(dt)
    bullet._update_homing_overlay(dt)


func _movement_config(type: BulletMovementConfig.MovementType) -> BulletMovementConfig:
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = type
  cfg.initial_speed = 500.0
  cfg.rotation_mode = BulletMovementConfig.RotationMode.MOVEMENT_DIRECTION
  return cfg


func _turn_from_up(bullet: Node2D) -> float:
  return absf(wrapf(bullet.direction.angle() - Vector2.UP.angle(), -PI, PI))


# =====================================================================
# 1. 既定値（既存弾への非干渉）
# =====================================================================


func test_pattern_homing_defaults() -> void:
  """AttackPattern の既定は追尾なし。既存の .tres は無変更で従来どおり動く"""
  var pattern := AttackPattern.new()

  assert_float(pattern.homing_correction_px).is_equal_approx(0.0, 0.0001)
  assert_float(pattern.homing_distance).is_equal_approx(DISTANCE, 0.0001)
  assert_float(pattern.homing_lock_angle_deg).is_equal_approx(60.0, 0.0001)
  assert_bool(pattern.homing_relock_on_target_lost).is_true()


func test_bullet_without_setup_flies_straight() -> void:
  """setup_homing を呼ばなければ、敵がいても方向は変わらない"""
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  _make_target(Vector2(700, 300))

  _advance(bullet, 60, 1.0 / 60.0)

  assert_float(_turn_from_up(bullet)).is_equal_approx(0.0, 0.0001)


func test_zero_correction_disables_homing() -> void:
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  _make_target(Vector2(700, 300))

  bullet.setup_homing(0.0, DISTANCE)
  _advance(bullet, 60, 1.0 / 60.0)

  assert_float(bullet._homing_radius).is_equal_approx(0.0, 0.0001)
  assert_float(_turn_from_up(bullet)).is_equal_approx(0.0, 0.0001)


# =====================================================================
# 2. 旋回半径の定義
# =====================================================================


func test_turn_radius_matches_formula() -> void:
  """r = homing_distance^2 / (2 * homing_correction_px)"""
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  _make_target(Vector2(700, 300))

  bullet.setup_homing(CORRECTION_L3, DISTANCE)

  assert_float(bullet._homing_radius).is_equal_approx(
    DISTANCE * DISTANCE / (2.0 * CORRECTION_L3), 0.01
  )


func test_higher_level_turns_more() -> void:
  """補正量が大きいレベルほど、同じ距離を飛ぶ間に大きく曲がる"""
  _make_target(Vector2(700, 100))
  var lv1 := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  var lv2 := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  var lv3 := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  lv1.setup_homing(CORRECTION_L1, DISTANCE)
  lv2.setup_homing(CORRECTION_L2, DISTANCE)
  lv3.setup_homing(CORRECTION_L3, DISTANCE)

  # 2px/step × 100step = 200px 進める
  for bullet in [lv1, lv2, lv3]:
    _advance(bullet, 100, 2.0 / 500.0)

  assert_float(_turn_from_up(lv1)).is_greater(0.0)
  assert_float(_turn_from_up(lv2)).is_greater(_turn_from_up(lv1))
  assert_float(_turn_from_up(lv3)).is_greater(_turn_from_up(lv2))


# =====================================================================
# 3. 弾速非依存（曲率ベース設計の核）
# =====================================================================


func test_trajectory_is_speed_independent() -> void:
  """弾速が4倍違っても、同じ距離を飛んだ時点の向きと位置はほぼ一致する"""
  var start := Vector2(400, 900)
  var step_px := 2.0
  var steps := 100  # 200px 分
  _make_target(Vector2(700, 100))

  var slow := _make_bullet(start, Vector2.UP, 250.0)
  slow.setup_homing(CORRECTION_L3, DISTANCE)
  _advance(slow, steps, step_px / 250.0)

  var fast := _make_bullet(start, Vector2.UP, 1000.0)
  fast.setup_homing(CORRECTION_L3, DISTANCE)
  _advance(fast, steps, step_px / 1000.0)

  assert_float(_turn_from_up(slow)).is_greater(0.0)
  assert_float(_turn_from_up(fast)).is_equal_approx(_turn_from_up(slow), 0.001)
  assert_float(fast.global_position.distance_to(slow.global_position)).is_less(1.0)


# =====================================================================
# 4. ロック条件
# =====================================================================


func test_locks_nearest_target() -> void:
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  _make_target(Vector2(420, 300))
  var near := _make_target(Vector2(420, 700))

  bullet.setup_homing(CORRECTION_L3, DISTANCE)

  assert_object(bullet._homing_target).is_same(near)


func test_does_not_lock_target_behind() -> void:
  """進行方向から離れすぎた敵（後方・真横）は、曲げても当たらないのでロックしない"""
  var bullet := _make_bullet(Vector2(400, 500), Vector2.UP, 500.0)
  _make_target(Vector2(400, 900))  # 真後ろ

  bullet.setup_homing(CORRECTION_L3, DISTANCE)

  assert_object(bullet._homing_target).is_null()


func test_does_not_lock_offscreen_target() -> void:
  """画面外で待機中のスポーン直後の敵はロックしない"""
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  _make_target(Vector2(420, -400))  # 画面上端の外側

  bullet.setup_homing(CORRECTION_L3, DISTANCE)

  assert_object(bullet._homing_target).is_null()


func test_does_not_lock_dead_target() -> void:
  """撃破処理中でまだグループに残っている敵はロックしない"""
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  _make_target(Vector2(420, 700), true)
  var alive := _make_target(Vector2(420, 300))

  bullet.setup_homing(CORRECTION_L3, DISTANCE)

  assert_object(bullet._homing_target).is_same(alive)


# =====================================================================
# 5. 追尾距離
# =====================================================================


func test_homing_stops_after_distance() -> void:
  """追尾距離を飛び切ったら、以後は曲がらず直進する"""
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  _make_target(Vector2(700, 100))
  bullet.setup_homing(CORRECTION_L3, 100.0)

  _advance(bullet, 60, 2.0 / 500.0)  # 120px = 追尾距離を超える
  var angle_after_window := _turn_from_up(bullet)
  _advance(bullet, 120, 2.0 / 500.0)

  assert_float(angle_after_window).is_greater(0.0)
  assert_float(bullet._homing_radius).is_equal_approx(0.0, 0.0001)
  assert_float(_turn_from_up(bullet)).is_equal_approx(angle_after_window, 0.0001)


# =====================================================================
# 6. ターゲット消失
# =====================================================================


func test_relocks_when_target_is_removed() -> void:
  """撃破済みの敵を追い続けて弾が無駄になるのを防ぐため、消失時は捉え直す"""
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  var first := _make_target(Vector2(420, 700))
  var second := _make_target(Vector2(420, 300))
  bullet.setup_homing(CORRECTION_L3, DISTANCE)
  assert_object(bullet._homing_target).is_same(first)

  _scene.remove_child(first)
  _advance(bullet, 1, 1.0 / 60.0)

  assert_object(bullet._homing_target).is_same(second)


func test_no_relock_flies_straight() -> void:
  var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0)
  var first := _make_target(Vector2(420, 700))
  _make_target(Vector2(700, 300))
  bullet.setup_homing(CORRECTION_L3, DISTANCE, 60.0, 180.0, false)

  _scene.remove_child(first)
  _advance(bullet, 1, 1.0 / 60.0)
  var angle_after_loss := _turn_from_up(bullet)
  _advance(bullet, 60, 1.0 / 60.0)

  assert_object(bullet._homing_target).is_null()
  assert_float(bullet._homing_radius).is_equal_approx(0.0, 0.0001)
  assert_float(_turn_from_up(bullet)).is_equal_approx(angle_after_loss, 0.0001)


# =====================================================================
# 7. 移動タイプとの組み合わせ
# =====================================================================


func test_spiral_and_boomerang_are_excluded() -> void:
  """独自の座標計算で動く移動タイプには追尾を適用しない（本来の軌道を壊さない）"""
  _make_target(Vector2(700, 300))

  for type in [
    BulletMovementConfig.MovementType.SPIRAL, BulletMovementConfig.MovementType.BOOMERANG
  ]:
    var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0, _movement_config(type))

    bullet.setup_homing(CORRECTION_L3, DISTANCE)

    assert_float(bullet._homing_radius).is_equal_approx(0.0, 0.0001)
    assert_object(bullet._homing_target).is_null()


func test_direction_driven_movement_types_are_supported() -> void:
  _make_target(Vector2(700, 300))

  for type in [
    BulletMovementConfig.MovementType.STRAIGHT,
    BulletMovementConfig.MovementType.DECELERATE,
    BulletMovementConfig.MovementType.ACCELERATE,
    BulletMovementConfig.MovementType.SINE_WAVE
  ]:
    var bullet := _make_bullet(Vector2(400, 900), Vector2.UP, 500.0, _movement_config(type))

    bullet.setup_homing(CORRECTION_L3, DISTANCE)

    assert_float(bullet._homing_radius).is_greater(0.0)
    assert_object(bullet._homing_target).is_not_null()


func test_gravity_bends_velocity_vector() -> void:
  """GRAVITY は direction ではなく _velocity で動くため、速度ベクトル側を曲げる"""
  var cfg := _movement_config(BulletMovementConfig.MovementType.GRAVITY)
  _make_target(Vector2(700, 200))
  var control := _make_bullet(Vector2(400, 500), Vector2.UP, 500.0, cfg)
  var homing := _make_bullet(Vector2(400, 500), Vector2.UP, 500.0, cfg)
  homing.setup_homing(CORRECTION_L3, DISTANCE)

  _advance_gravity(control, 30, 1.0 / 60.0)
  _advance_gravity(homing, 30, 1.0 / 60.0)

  assert_object(homing._homing_target).is_not_null()
  assert_float(control._velocity.x).is_equal_approx(0.0, 0.0001)
  assert_float(homing._velocity.x).is_greater(0.0)


# =====================================================================
# 8. エンチャント定義とファクトリー連携
# =====================================================================


func test_enchantment_tier_values() -> void:
  var enchant: Enchantment = load(ENCHANT_PATH)

  assert_str(str(enchant.id)).is_equal("homing_correction_px_add")
  assert_float(enchant.get_modifiers(1)["homing_correction_px_add"]).is_equal_approx(
    CORRECTION_L1, 0.01
  )
  assert_float(enchant.get_modifiers(2)["homing_correction_px_add"]).is_equal_approx(
    CORRECTION_L2, 0.01
  )
  assert_float(enchant.get_modifiers(3)["homing_correction_px_add"]).is_equal_approx(
    CORRECTION_L3, 0.01
  )


func _make_item_instance(level: int) -> ItemInstance:
  var proto := AttackCoreItem.new()
  proto.damage_base = 1.0
  proto.cooldown_sec_base = 0.2
  proto.base_modifiers = {"bullet_speed": 1000.0}
  var inst := ItemInstance.new(proto)
  if level > 0:
    inst.add_enchantment(load(ENCHANT_PATH), level)
  return inst


func test_factory_applies_homing_from_enchantment() -> void:
  var inst := _make_item_instance(2)
  var pattern := PlayerAttackPatternFactory.create_pattern_from_item_instance(inst)

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)

  assert_float(pattern.homing_correction_px).is_equal_approx(CORRECTION_L2, 0.01)


func test_factory_without_enchantment_leaves_homing_off() -> void:
  var inst := _make_item_instance(0)
  var pattern := PlayerAttackPatternFactory.create_pattern_from_item_instance(inst)

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)

  assert_float(pattern.homing_correction_px).is_equal_approx(0.0, 0.0001)


func test_factory_update_is_idempotent() -> void:
  """再計算のたびに補正量が加算されていかないこと"""
  var inst := _make_item_instance(3)
  var pattern := PlayerAttackPatternFactory.create_pattern_from_item_instance(inst)

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)

  assert_float(pattern.homing_correction_px).is_equal_approx(CORRECTION_L3, 0.01)
