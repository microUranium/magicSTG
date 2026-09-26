# === ブーメラン機能テスト ===
# テスト対象:
#   1. BulletMovementConfig.MovementType.BOOMERANG と固有パラメータの存在
#   2. 往路：initial_speed から線形に減速し boomerang_outbound_time で停止する
#   3. 復路：プレイヤー方向へ向き直し boomerang_return_max_speed まで加速する
#   4. 回収：boomerang_catch_radius 内で削除される／往路では回収されない
#   5. プレイヤー不在時は向きを維持して直進する
#   6. 既存の移動タイプ（STRAIGHT / GRAVITY）が影響を受けていない
extends GdUnitTestSuite
class_name BoomerangFeatureTest

const BULLET_SCENE := "res://scenes/bullets/universal_bullet.tscn"

const OUTBOUND_TIME := 0.75
const INITIAL_SPEED := 1200.0
const RETURN_ACCEL := 1800.0
const RETURN_MAX_SPEED := 1000.0
const CATCH_RADIUS := 24.0

var _scene: Node2D
var _bullet: Node2D
var _player: Node2D


func before_test() -> void:
  _scene = auto_free(Node2D.new())
  add_child(_scene)

  _player = auto_free(Node2D.new())
  _player.global_position = Vector2(400, 700)
  _scene.add_child(_player)

  _bullet = auto_free(load(BULLET_SCENE).instantiate())
  _scene.add_child(_bullet)
  # エンジンの _process と手動駆動が二重に走らないよう止める。
  # 各テストは _update_advanced_movement() を直接呼んでフレームを進める。
  _bullet.set_process(false)
  _bullet.global_position = Vector2(400, 400)
  _bullet.direction = Vector2(0, -1)
  _bullet.apply_movement_config(_make_boomerang_config())


func after_test() -> void:
  TargetService.unregister_player()


func _make_boomerang_config() -> BulletMovementConfig:
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = BulletMovementConfig.MovementType.BOOMERANG
  cfg.initial_speed = INITIAL_SPEED
  cfg.boomerang_outbound_time = OUTBOUND_TIME
  cfg.boomerang_return_accel = RETURN_ACCEL
  cfg.boomerang_return_max_speed = RETURN_MAX_SPEED
  cfg.boomerang_catch_radius = CATCH_RADIUS
  cfg.rotation_mode = BulletMovementConfig.RotationMode.SELF_ROTATION
  cfg.angular_velocity = 720.0
  return cfg


func _advance(seconds: float, dt: float = 1.0 / 60.0) -> void:
  """指定秒数ぶん _update_advanced_movement() を回す（移動はしない）"""
  var frames := int(round(seconds / dt))
  for _i in frames:
    _bullet._update_advanced_movement(dt)


func _enter_return_phase(dt: float = 1.0 / 60.0) -> int:
  """帰還フェーズに切り替わるまでフレームを進め、要したフレーム数を返す。

  dt の累積は浮動小数点誤差を持つため（1/60 を90回足すと 1.5 に僅かに届かない）、
  固定フレーム数ではなくフラグが立つまで回す。
  """
  var frames := 0
  while not _bullet._boomerang_returning and frames < 1000:
    _bullet._update_advanced_movement(dt)
    frames += 1
  return frames


# =====================================================================
# 1. パラメータの存在
# =====================================================================


func test_boomerang_movement_type_value() -> void:
  """BOOMERANG は末尾に追加された値7（既存の serialized 値を動かさない）"""
  assert_int(BulletMovementConfig.MovementType.BOOMERANG).is_equal(7)
  assert_int(BulletMovementConfig.MovementType.SPIRAL).is_equal(6)
  assert_int(BulletMovementConfig.MovementType.GRAVITY).is_equal(5)


func test_boomerang_params_exist_with_defaults() -> void:
  """固有パラメータが存在し、スクリプト側の既定値が保たれている
  （.tres の値はコア個別のチューニング値なので test_resource_file_loads で検証する）"""
  var cfg := BulletMovementConfig.new()
  assert_float(cfg.boomerang_outbound_time).is_equal_approx(1.5, 0.001)
  assert_float(cfg.boomerang_return_accel).is_equal_approx(900.0, 0.001)
  assert_float(cfg.boomerang_return_max_speed).is_equal_approx(700.0, 0.001)
  assert_float(cfg.boomerang_catch_radius).is_equal_approx(24.0, 0.001)


# =====================================================================
# 2. 往路：線形減速
# =====================================================================


func test_outbound_starts_at_initial_speed() -> void:
  assert_float(_bullet.speed).is_equal_approx(INITIAL_SPEED, 0.001)
  assert_bool(_bullet._boomerang_returning).is_false()


func test_outbound_decelerates_linearly() -> void:
  """往路の中間地点で速度が初速の約半分になる"""
  _advance(OUTBOUND_TIME * 0.5)

  assert_float(_bullet.speed).is_equal_approx(INITIAL_SPEED * 0.5, INITIAL_SPEED * 0.02)
  assert_bool(_bullet._boomerang_returning).is_false()


func test_outbound_reaches_zero_and_switches_to_return() -> void:
  """boomerang_outbound_time 経過で速度0・帰還フェーズへ移行する"""
  TargetService.unregister_player()  # 帰還後に回収されないようにする

  var dt := 1.0 / 60.0
  var frames := _enter_return_phase(dt)

  assert_bool(_bullet._boomerang_returning).is_true()
  # 切り替わった瞬間の速度は0（次フレームから加速が始まる）
  assert_float(_bullet.speed).is_equal_approx(0.0, 0.001)
  # 切り替わりは outbound_time の直後1フレーム以内
  assert_float(frames * dt).is_between(OUTBOUND_TIME, OUTBOUND_TIME + dt + 0.001)


func test_outbound_distance_matches_spec() -> void:
  """往路の到達距離が initial_speed * outbound_time / 2 になる

  ProjectileBullet._process() は「現在の speed で移動 → 速度更新」の順なので
  離散化により解析解より initial_speed * dt / 2 だけ大きくなる。
  """
  var dt := 1.0 / 60.0
  var distance := 0.0
  var frames := int(round(OUTBOUND_TIME / dt))
  for _i in frames:
    distance += _bullet.speed * dt
    _bullet._update_advanced_movement(dt)

  var analytic := INITIAL_SPEED * OUTBOUND_TIME / 2.0
  var expected := analytic + INITIAL_SPEED * dt / 2.0
  assert_float(analytic).is_equal_approx(450.0, 0.001)  # 飛距離は仕様どおり450px
  assert_float(distance).is_equal_approx(expected, 2.0)


# =====================================================================
# 3. 復路：プレイヤーへの追尾と加速
# =====================================================================


func test_return_phase_turns_toward_player() -> void:
  """復路では進行方向がプレイヤー方向へ向き直る（往路は上向きだった）"""
  TargetService.register_player(_player)
  _bullet.global_position = Vector2(400, 400)  # プレイヤー(400,700)の真上

  _enter_return_phase()
  _bullet._update_advanced_movement(1.0 / 60.0)

  # プレイヤーは弾の真下にいるので direction は下向き(0, 1)
  assert_float(_bullet.direction.y).is_greater(0.9)
  assert_float(_bullet.speed).is_greater(0.0)


func test_return_phase_accelerates() -> void:
  """復路で速度が boomerang_return_accel に従って増加する"""
  TargetService.register_player(_player)
  _enter_return_phase()

  var dt := 1.0 / 60.0
  _bullet._update_advanced_movement(dt)
  var speed_after_1_frame: float = _bullet.speed
  _bullet._update_advanced_movement(dt)
  var speed_after_2_frames: float = _bullet.speed

  assert_float(speed_after_1_frame).is_equal_approx(RETURN_ACCEL * dt, 1.0)
  assert_float(speed_after_2_frames).is_greater(speed_after_1_frame)


func test_return_speed_clamped_to_max() -> void:
  """加速し続けても boomerang_return_max_speed を超えない"""
  TargetService.unregister_player()  # 回収されずに加速し続ける状況
  _enter_return_phase()
  _advance(3.0)  # 十分に加速させる

  assert_float(_bullet.speed).is_equal_approx(RETURN_MAX_SPEED, 0.001)


# =====================================================================
# 4. 回収
# =====================================================================


func test_caught_within_catch_radius() -> void:
  """回収半径内に入ると弾が削除される"""
  TargetService.register_player(_player)
  _enter_return_phase()

  _bullet.global_position = _player.global_position + Vector2(0, CATCH_RADIUS - 4.0)
  _bullet._update_advanced_movement(1.0 / 60.0)

  assert_bool(_bullet.is_queued_for_deletion()).is_true()


func test_not_caught_outside_catch_radius() -> void:
  TargetService.register_player(_player)
  _enter_return_phase()

  _bullet.global_position = _player.global_position + Vector2(0, CATCH_RADIUS + 20.0)
  _bullet._update_advanced_movement(1.0 / 60.0)

  assert_bool(_bullet.is_queued_for_deletion()).is_false()


func test_not_caught_during_outbound() -> void:
  """往路では回収判定を行わない（発射直後に自機と重なっていても消えない）"""
  TargetService.register_player(_player)
  _bullet.global_position = _player.global_position  # 完全に重なっている

  _bullet._update_advanced_movement(1.0 / 60.0)

  assert_bool(_bullet._boomerang_returning).is_false()
  assert_bool(_bullet.is_queued_for_deletion()).is_false()


# =====================================================================
# 5. プレイヤー不在時
# =====================================================================


func test_player_absent_keeps_direction() -> void:
  """プレイヤー不在なら向きを変えず直進する（forced_lifetime に委ねる）"""
  TargetService.unregister_player()
  var dir_before: Vector2 = _bullet.direction

  _enter_return_phase()
  _advance(0.5)

  assert_bool(_bullet._boomerang_returning).is_true()
  assert_vector(_bullet.direction).is_equal_approx(dir_before, Vector2(0.001, 0.001))
  assert_bool(_bullet.is_queued_for_deletion()).is_false()


# =====================================================================
# 6. 既存移動タイプへの非干渉（回帰）
# =====================================================================


func test_straight_movement_unaffected() -> void:
  """STRAIGHT は速度が変化しない"""
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = BulletMovementConfig.MovementType.STRAIGHT
  cfg.initial_speed = 300.0
  _bullet.apply_movement_config(cfg)

  _advance(1.0)

  assert_float(_bullet.speed).is_equal_approx(300.0, 0.001)


func test_gravity_speed_is_zeroed() -> void:
  """GRAVITY は移動を _velocity に一本化するため speed = 0 になる
  （二重移動修正の回帰テスト）"""
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = BulletMovementConfig.MovementType.GRAVITY
  cfg.initial_speed = 400.0
  _bullet.direction = Vector2(0, -1)
  _bullet.apply_movement_config(cfg)

  assert_float(_bullet.speed).is_equal_approx(0.0, 0.001)
  assert_vector(_bullet._velocity).is_equal_approx(Vector2(0, -400), Vector2(0.001, 0.001))


func test_gravity_accumulates_moving_distance() -> void:
  """speed = 0 でも bullet_range が機能するよう _moving_distance が伸びる"""
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = BulletMovementConfig.MovementType.GRAVITY
  cfg.initial_speed = 400.0
  cfg.gravity_strength = 0.0  # 等速にして計算を単純化
  _bullet.direction = Vector2(0, -1)
  _bullet.apply_movement_config(cfg)

  _advance(1.0)

  # 400px/s で1秒 → 約400px
  assert_float(_bullet._moving_distance).is_between(395.0, 405.0)


# =====================================================================
# 7. リソース
# =====================================================================


func test_resource_file_loads() -> void:
  """attackcore_boomerang.tres がエラーなくロードでき、値が仕様どおり"""
  var core = load("res://resources/data/attackcore_boomerang.tres")

  assert_object(core).is_not_null()
  assert_str(str(core.id)).is_equal("attackcore_boomerang")
  assert_float(core.damage_base).is_equal_approx(3.0, 0.001)
  assert_float(core.cooldown_sec_base).is_equal_approx(1.0, 0.001)
  assert_float(core.base_modifiers.get("bullet_speed", 0.0)).is_equal_approx(INITIAL_SPEED, 0.001)

  var pattern: AttackPattern = core.attack_pattern
  assert_object(pattern).is_not_null()
  assert_int(pattern.penetration_count).is_equal(3)
  assert_bool(pattern.persist_offscreen).is_true()
  assert_float(pattern.forced_lifetime).is_equal_approx(8.0, 0.001)

  var move_cfg: BulletMovementConfig = pattern.bullet_movement_config
  assert_object(move_cfg).is_not_null()
  assert_int(move_cfg.movement_type).is_equal(BulletMovementConfig.MovementType.BOOMERANG)
  # movement_config が指定されている場合 initial_speed が speed を上書きするため
  # base_modifiers.bullet_speed と一致していなければならない
  assert_float(move_cfg.initial_speed).is_equal_approx(INITIAL_SPEED, 0.001)
  assert_float(move_cfg.boomerang_outbound_time).is_equal_approx(OUTBOUND_TIME, 0.001)
  assert_float(move_cfg.boomerang_return_accel).is_equal_approx(RETURN_ACCEL, 0.001)
  assert_float(move_cfg.boomerang_return_max_speed).is_equal_approx(RETURN_MAX_SPEED, 0.001)


# =====================================================================
# 残像
# =====================================================================


func _afterimage_count() -> int:
  """シーンに存在する残像ノード数を数える"""
  var tree := get_tree()
  var root: Node = tree.current_scene if tree.current_scene else tree.root
  var n := 0
  for child in root.get_children():
    if child is AfterImage:
      n += 1
  return n


func _make_afterimage_bullet(interval: float = 0.04) -> Node2D:
  var bullet: Node2D = auto_free(load(BULLET_SCENE).instantiate())
  var visual := BulletVisualConfig.new()
  visual.texture = PlaceholderTexture2D.new()
  visual.scale = 2.0
  visual.enable_afterimage = true
  visual.afterimage_interval = interval
  visual.afterimage_lifetime = 0.25
  visual.afterimage_color = Color(1, 1, 1, 0.45)
  _scene.add_child(bullet)
  bullet.set_process(false)
  bullet.global_position = Vector2(400, 400)
  bullet.direction = Vector2(0, -1)
  bullet.apply_visual_config(visual)
  bullet.apply_movement_config(_make_boomerang_config())
  return bullet


func test_afterimage_disabled_by_default() -> void:
  """既定では残像を出さない（既存の弾は無変更で従来どおり）"""
  assert_bool(BulletVisualConfig.new().enable_afterimage).is_false()

  var before := _afterimage_count()
  for _i in 60:
    _bullet._update_afterimage(1.0 / 60.0)

  assert_int(_afterimage_count()).is_equal(before)


func test_afterimage_spawns_at_interval() -> void:
  """interval ごとに1枚生成される（0.04秒間隔・0.4秒で約10枚）"""
  var bullet := _make_afterimage_bullet(0.04)
  var before := _afterimage_count()

  for _i in 24:  # 0.4秒
    bullet._update_afterimage(1.0 / 60.0)

  # 累積は1フレーム分ぶれるので幅を持たせる
  assert_int(_afterimage_count() - before).is_between(8, 10)


func test_afterimage_capped_to_one_per_frame() -> void:
  """巨大な delta でも1フレームに1枚まで（積み残しは捨てる）"""
  var bullet := _make_afterimage_bullet(0.04)
  var before := _afterimage_count()

  bullet._update_afterimage(10.0)  # 本来なら250枚

  assert_int(_afterimage_count() - before).is_equal(1)


func test_afterimage_copies_sprite_transform() -> void:
  """残像が弾のスプライトの位置・回転・スケール・テクスチャを複製する"""
  var bullet := _make_afterimage_bullet(0.01)
  bullet.global_position = Vector2(300, 250)
  bullet.rotation = deg_to_rad(37.0)
  var before := _afterimage_count()

  bullet._update_afterimage(0.02)
  assert_int(_afterimage_count() - before).is_equal(1)

  var tree := get_tree()
  var root: Node = tree.current_scene if tree.current_scene else tree.root
  var newest: AfterImage = null
  for child in root.get_children():
    if child is AfterImage:
      newest = child
  assert_object(newest).is_not_null()
  assert_vector(newest.global_position).is_equal_approx(
    bullet.sprite.global_position, Vector2(0.5, 0.5)
  )
  assert_float(newest.global_rotation).is_equal_approx(bullet.sprite.global_rotation, 0.001)
  assert_vector(newest.scale).is_equal_approx(bullet.sprite.scale, Vector2(0.001, 0.001))
  assert_object(newest.texture).is_same(bullet.sprite.texture)
  assert_float(newest.modulate.a).is_equal_approx(0.45, 0.001)
  newest.free()


func test_afterimage_survives_bullet_removal() -> void:
  """残像は弾の子ではないので、弾が消えても残る"""
  var bullet := _make_afterimage_bullet(0.01)
  bullet._update_afterimage(0.02)
  var count := _afterimage_count()
  assert_int(count).is_greater(0)

  bullet.queue_free()
  await await_idle_frame()

  assert_int(_afterimage_count()).is_equal(count)


func test_boomerang_resource_enables_afterimage() -> void:
  var core = load("res://resources/data/attackcore_boomerang.tres")
  var visual: BulletVisualConfig = core.attack_pattern.bullet_visual_config

  assert_bool(visual.enable_afterimage).is_true()
  assert_float(visual.afterimage_interval).is_greater(0.0)
  assert_float(visual.afterimage_lifetime).is_greater(0.0)
  # 弾本体より薄くないと残像に見えない
  assert_float(visual.afterimage_color.a).is_less(1.0)


func test_return_speed_cannot_skip_catch_radius() -> void:
  """1フレームの移動量が回収判定をすり抜けない余裕があること

  正面から近づく場合、距離 d から d - step へ移動して両方が半径外になるには
  step > 2 * catch_radius が必要。したがって step < 2 * catch_radius なら
  必ずどこかのフレームで半径内に入る。復路速度を上げる際の上限条件。
  """
  var step_per_frame := RETURN_MAX_SPEED / 60.0

  assert_float(step_per_frame).is_less(CATCH_RADIUS * 2.0)


func test_return_max_speed_exceeds_player_speed() -> void:
  """帰還速度がプレイヤー移動速度を上回っていること（下回ると回収されず滞留する）"""
  var player_scene = load("res://scenes/player/player.tscn")
  var player = auto_free(player_scene.instantiate())

  assert_float(RETURN_MAX_SPEED).is_greater(player.speed)
