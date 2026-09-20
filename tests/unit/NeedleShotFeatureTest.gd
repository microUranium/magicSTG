# === ニードルショット機能テスト ===
# テスト対象:
#   1. contact_damage_tick_sec / contact_speed の既定値（既存弾への非干渉）
#   2. 接触中に一定間隔でダメージが入る（進入時1回ではない）
#   3. ダメージ間隔が時間ベースでフレームレート非依存
#   4. tick モードでは貫通判定を通らない（貫通エンチャントの影響を受けない）
#   5. 接触中は速度が contact_speed に固定される（敵が重なっても維持）
#   6. 通常弾（tick 0）の挙動が変わっていない
extends GdUnitTestSuite
class_name NeedleShotFeatureTest

const BULLET_SCENE := "res://scenes/bullets/universal_bullet.tscn"

const TICK := 1.0 / 30.0
const DMG := 2
const CONTACT_SPEED := 200.0
const INITIAL_SPEED := 200.0
const ACCEL := 600.0
const MAX_SPEED := 500.0
const DT := 1.0 / 60.0


class DamageTarget:
  extends Area2D
  var received: int = 0
  var hit_count: int = 0

  func take_damage(amount: int) -> void:
    received += amount
    hit_count += 1


var _scene: Node2D


func before_test() -> void:
  _scene = auto_free(Node2D.new())
  add_child(_scene)


func _make_target() -> DamageTarget:
  var t := DamageTarget.new()
  t.add_to_group("enemies")
  _scene.add_child(t)
  auto_free(t)
  return t


func _make_config(contact: float = CONTACT_SPEED) -> BulletMovementConfig:
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = BulletMovementConfig.MovementType.ACCELERATE
  cfg.initial_speed = INITIAL_SPEED
  cfg.acceleration_rate = ACCEL
  cfg.max_speed = MAX_SPEED
  cfg.contact_speed = contact
  cfg.rotation_mode = BulletMovementConfig.RotationMode.MOVEMENT_DIRECTION
  return cfg


func _make_bullet(tick_sec: float = TICK, cfg: BulletMovementConfig = null) -> Node2D:
  var bullet: Node2D = auto_free(load(BULLET_SCENE).instantiate())
  _scene.add_child(bullet)
  bullet.set_process(false)  # 手動でフレームを進める
  bullet.direction = Vector2(0, -1)
  bullet.damage = DMG
  bullet.target_group = "enemies"
  bullet.penetration_count = -1
  bullet.apply_movement_config(cfg if cfg else _make_config())
  if tick_sec > 0.0:
    bullet.enable_contact_damage(tick_sec)
  return bullet


func _tick(bullet: Node2D, seconds: float, dt: float = DT) -> void:
  for _i in int(round(seconds / dt)):
    bullet._update_contact_damage(dt)


# =====================================================================
# 1. 既定値（既存弾への非干渉）
# =====================================================================


func test_defaults_are_disabled() -> void:
  """両パラメータの既定は無効。既存の .tres / シーンは無変更で従来どおり動く"""
  assert_float(AttackPattern.new().contact_damage_tick_sec).is_equal_approx(0.0, 0.0001)
  assert_float(BulletMovementConfig.new().contact_speed).is_equal_approx(0.0, 0.0001)


func test_area_exited_not_connected_for_normal_bullets() -> void:
  """通常弾には area_exited を接続しない（大量発射時のコスト対策）"""
  var bullet := _make_bullet(0.0)

  assert_bool(bullet.area_exited.is_connected(bullet._on_area_exited)).is_false()


func test_area_exited_connected_in_tick_mode() -> void:
  var bullet := _make_bullet(TICK)

  assert_bool(bullet.area_exited.is_connected(bullet._on_area_exited)).is_true()


# =====================================================================
# 2. 接触中の継続ダメージ
# =====================================================================


func test_entry_alone_deals_no_damage() -> void:
  """tick モードでは進入した瞬間にはダメージが入らない"""
  var bullet := _make_bullet()
  var target := _make_target()

  bullet._on_area_entered(target)

  assert_int(target.received).is_equal(0)
  assert_int(target.hit_count).is_equal(0)


func test_tick_applies_damage_while_touching() -> void:
  """接触中は 1/30 秒ごとに damage が入る（1秒で 30回 = 60ダメージ）"""
  var bullet := _make_bullet()
  var target := _make_target()
  bullet._on_area_entered(target)

  _tick(bullet, 1.0)

  assert_int(target.hit_count).is_equal(30)
  assert_int(target.received).is_equal(60)


func test_damage_stops_after_exit() -> void:
  var bullet := _make_bullet()
  var target := _make_target()
  bullet._on_area_entered(target)
  _tick(bullet, 0.5)
  var mid: int = target.received

  bullet._on_area_exited(target)
  _tick(bullet, 1.0)

  assert_int(mid).is_greater(0)
  assert_int(target.received).is_equal(mid)


func test_all_touching_targets_are_damaged() -> void:
  """複数の敵に同時に接触している間は全員にダメージが入る（無限貫通）"""
  var bullet := _make_bullet()
  var a := _make_target()
  var b := _make_target()
  bullet._on_area_entered(a)
  bullet._on_area_entered(b)

  _tick(bullet, 0.5)

  assert_int(a.received).is_equal(30)
  assert_int(b.received).is_equal(30)


func test_same_target_registered_once() -> void:
  """同じ敵が二重登録されない（二重ダメージ防止）"""
  var bullet := _make_bullet()
  var target := _make_target()
  bullet._on_area_entered(target)
  bullet._on_area_entered(target)

  _tick(bullet, 0.5)

  assert_int(target.received).is_equal(30)


func test_freed_target_is_pruned() -> void:
  """撃破された敵が除去され、無効インスタンスへの take_damage が起きない"""
  var bullet := _make_bullet()
  var target := DamageTarget.new()
  target.add_to_group("enemies")
  _scene.add_child(target)
  bullet._on_area_entered(target)
  _tick(bullet, 0.2)

  target.free()
  _tick(bullet, 0.5)  # クラッシュしないこと

  assert_int(bullet._contact_targets.size()).is_equal(0)


# =====================================================================
# 3. 時間ベース（フレームレート非依存）
# =====================================================================


func test_tick_is_frame_rate_independent() -> void:
  """dt が変わっても1秒あたりのダメージ量が変わらない。

  project.godot に max_fps / vsync の指定がないため _process はモニタの
  リフレッシュレートで回る。フレーム数で数えると144Hz環境で火力が2.4倍になる。
  """
  var results := {}
  for dt in [1.0 / 60.0, 1.0 / 144.0, 1.0 / 30.0, 1.0 / 240.0]:
    var bullet := _make_bullet()
    var target := _make_target()
    bullet._on_area_entered(target)
    _tick(bullet, 1.0, dt)
    results[dt] = target.received

  # tick 数は floor(経過時間 / tick_sec) なので境界で ±1 tick（=2ダメージ）ぶれる。
  # 検証したいのは「dt によって桁が変わらないこと」。フレームカウンタで実装すると
  # 144Hz で 2.4 倍（144ダメージ）になるため、この範囲チェックで十分に検出できる。
  var values: Array = results.values()
  for dt in results:
    var msg := "dt=1/%d で %d ダメージ（期待 58〜60）" % [int(round(1.0 / dt)), results[dt]]
    assert_int(results[dt]).override_failure_message(msg).is_between(58, 60)
  assert_int(values.max() - values.min()).is_between(0, 2)


func test_ticks_per_frame_are_capped() -> void:
  """巨大な delta（ハング明け）でも1フレームの tick 数に上限がある"""
  var bullet := _make_bullet()
  var target := _make_target()
  bullet._on_area_entered(target)

  bullet._update_contact_damage(10.0)  # 本来なら300 tick

  assert_int(target.hit_count).is_equal(BulletBase.MAX_CONTACT_TICKS_PER_FRAME)
  # 積み残しは捨てられる
  assert_float(bullet._contact_tick_accum).is_equal_approx(0.0, 0.0001)


# =====================================================================
# 4. 貫通判定を通らない
# =====================================================================


func test_bullet_survives_contact_in_tick_mode() -> void:
  """penetration_count = 0（貫通なし）でも接触で消滅しない"""
  var bullet := _make_bullet()
  bullet.penetration_count = 0
  var target := _make_target()

  bullet._on_area_entered(target)

  assert_bool(bullet.is_queued_for_deletion()).is_false()
  assert_int(bullet.hit_count).is_equal(0)  # hit_count も増えない


func test_penetration_enchant_has_no_effect() -> void:
  """貫通エンチャントで penetration_count が書き換わっても挙動が変わらない。

  PlayerAttackPatternFactory は penetration_count に penetration_add を
  単純加算するため -1（無限）は有限値に化ける（-1 + 1 = 0）。
  tick モードは貫通判定を通らないので、この書き換えは無害になる。
  """
  for pen in [-1, 0, 1, 3]:
    var bullet := _make_bullet()
    bullet.penetration_count = pen
    var target := _make_target()

    bullet._on_area_entered(target)
    _tick(bullet, 0.5)

    var msg := "penetration_count = %d で弾が消滅した" % pen
    assert_bool(bullet.is_queued_for_deletion()).override_failure_message(msg).is_false()
    assert_int(target.received).is_equal(30)


# =====================================================================
# 5. contact_speed
# =====================================================================


func test_speed_forced_to_contact_speed_while_touching() -> void:
  """接触中は速度が contact_speed に固定される"""
  var bullet := _make_bullet()
  # まず加速させる
  for _i in 30:
    bullet._update_advanced_movement(DT)
  var accelerated: float = bullet.speed
  assert_float(accelerated).is_greater(INITIAL_SPEED)

  bullet._on_area_entered(_make_target())
  bullet._update_advanced_movement(DT)

  assert_float(bullet.speed).is_equal_approx(CONTACT_SPEED, 0.001)


func test_speed_resumes_acceleration_after_exit() -> void:
  var bullet := _make_bullet()
  var target := _make_target()
  bullet._on_area_entered(target)
  bullet._update_advanced_movement(DT)
  assert_float(bullet.speed).is_equal_approx(CONTACT_SPEED, 0.001)

  bullet._on_area_exited(target)
  for _i in 30:
    bullet._update_advanced_movement(DT)

  assert_float(bullet.speed).is_greater(CONTACT_SPEED)


func test_stacked_enemies_keep_contact_speed() -> void:
  """敵が縦に重なっていても接触対象が残っている間は 200px/s のまま貫く"""
  var bullet := _make_bullet()
  var a := _make_target()
  var b := _make_target()
  bullet._on_area_entered(a)
  bullet._on_area_entered(b)

  # 1体目を抜けても2体目に接触中なので低速のまま
  bullet._on_area_exited(a)
  for _i in 30:
    bullet._update_advanced_movement(DT)

  assert_float(bullet.speed).is_equal_approx(CONTACT_SPEED, 0.001)

  # 2体目も抜けたら再加速する
  bullet._on_area_exited(b)
  for _i in 30:
    bullet._update_advanced_movement(DT)
  assert_float(bullet.speed).is_greater(CONTACT_SPEED)


func test_contact_speed_zero_does_not_override() -> void:
  """contact_speed = 0（既定）なら速度を上書きしない（既存弾への非干渉）"""
  var bullet := _make_bullet(TICK, _make_config(0.0))
  bullet._on_area_entered(_make_target())

  for _i in 30:
    bullet._update_advanced_movement(DT)

  assert_float(bullet.speed).is_greater(INITIAL_SPEED)


# =====================================================================
# 6. 通常弾の回帰
# =====================================================================


func test_normal_bullet_damages_on_entry() -> void:
  """tick 0 の弾は従来どおり進入時に1回ダメージを与える"""
  var bullet := _make_bullet(0.0)
  bullet.penetration_count = 0
  var target := _make_target()

  bullet._on_area_entered(target)

  assert_int(target.received).is_equal(DMG)
  assert_int(bullet.hit_count).is_equal(1)
  # 貫通なしなので消滅する
  assert_bool(bullet.is_queued_for_deletion()).is_true()


func test_normal_bullet_penetration_still_works() -> void:
  """貫通判定が従来どおり働くこと。

  BulletBase の判定は `hit_count > penetration_count` なので、
  penetration_count = 2 の弾は 1体目・2体目を貫通し **3体目で消滅する**
  （合計3体にダメージを与える）。
  """
  var bullet := _make_bullet(0.0)
  bullet.penetration_count = 2

  for i in 2:
    bullet._on_area_entered(_make_target())
    var msg := "%d体目で消滅した（3体目まで生存するはず）" % (i + 1)
    assert_bool(bullet.is_queued_for_deletion()).override_failure_message(msg).is_false()

  bullet._on_area_entered(_make_target())
  assert_bool(bullet.is_queued_for_deletion()).is_true()
  assert_int(bullet.hit_count).is_equal(3)


func test_normal_bullet_tick_is_noop() -> void:
  """tick 0 の弾で _update_contact_damage を呼んでも何も起きない"""
  var bullet := _make_bullet(0.0)
  bullet.penetration_count = -1
  var target := _make_target()
  bullet._on_area_entered(target)
  var after_entry: int = target.received

  _tick(bullet, 1.0)

  assert_int(target.received).is_equal(after_entry)


# =====================================================================
# 7. リソースと数値
# =====================================================================


func test_resource_file_loads() -> void:
  var core = load("res://resources/data/attackcore_needleshot.tres")

  assert_object(core).is_not_null()
  assert_str(str(core.id)).is_equal("attackcore_needleshot")
  assert_float(core.damage_base).is_equal_approx(2.0, 0.001)
  assert_float(core.cooldown_sec_base).is_equal_approx(1.5, 0.001)

  var pattern: AttackPattern = core.attack_pattern
  assert_float(pattern.contact_damage_tick_sec).is_equal_approx(TICK, 0.0001)
  assert_int(pattern.penetration_count).is_equal(-1)
  assert_float(pattern.bullet_lifetime).is_equal_approx(0.0, 0.001)
  # bullet_lifetime = 0（無限）と併用するため persist_offscreen は false 必須。
  # true にすると弾が永久残留する。
  assert_bool(pattern.persist_offscreen).is_false()

  var cfg: BulletMovementConfig = pattern.bullet_movement_config
  assert_int(cfg.movement_type).is_equal(BulletMovementConfig.MovementType.ACCELERATE)
  assert_float(cfg.contact_speed).is_equal_approx(CONTACT_SPEED, 0.001)
  assert_float(cfg.initial_speed).is_equal_approx(INITIAL_SPEED, 0.001)
  # 既定の acceleration_rate 50 では 200->500 に6秒かかり加速が見えない
  assert_float(cfg.acceleration_rate).is_equal_approx(ACCEL, 0.001)
  # movement_config が speed を上書きするため base_modifiers と一致させる
  assert_float(core.base_modifiers.get("bullet_speed", 0.0)).is_equal_approx(INITIAL_SPEED, 0.001)


func test_damage_per_shot_matches_spec() -> void:
  """1発あたりのダメージが仕様書3章の表と一致すること。

  1発のダメージ = damage x floor(通過距離 / contact_speed / tick)
  通過距離 = 敵の縦幅 + 弾半径 x 2（弾半径 6）
  """
  var cases := {
    "ボス doll (h144)": [144.0, 46],
    "雑魚 44x70": [70.0, 24],
    "雑魚 42x66": [66.0, 22],
  }
  for label in cases:
    var enemy_height: float = cases[label][0]
    var expected: int = cases[label][1]
    var dwell := (enemy_height + 6.0 * 2.0) / CONTACT_SPEED

    var bullet := _make_bullet()
    var target := _make_target()
    bullet._on_area_entered(target)
    _tick(bullet, dwell)

    var msg := "%s: 期待 %d / 実測 %d" % [label, expected, target.received]
    assert_int(target.received).override_failure_message(msg).is_equal(expected)
