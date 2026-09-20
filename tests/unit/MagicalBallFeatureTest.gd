# === マジカルボール機能テスト ===
# テスト対象:
#   1. gravity_follows_direction フラグの存在と既定値
#   2. 重力方向が弾の初期進行方向のY符号に追従すること（上撃ち→上向き / 後方発射→下向き）
#   3. 共有サブリソース（movement_config）を書き換えないこと
#   4. GRAVITY + バウンドで壁に張り付かないこと（Step1 の二重移動修正の帰結）
#   5. 4辺すべてでバウンドすること
#   6. 既定 false のとき従来どおり gravity_direction を使うこと（回帰）
extends GdUnitTestSuite
class_name MagicalBallFeatureTest

const BULLET_SCENE := "res://scenes/bullets/universal_bullet.tscn"

const INITIAL_SPEED := 250.0
const GRAVITY_STRENGTH := 600.0
const BOUNCE_FACTOR := 0.5
const DT := 1.0 / 60.0

# 実機のプレイ領域（viewport 1280x960 - hud_width 384）
const PLAY_RECT := Rect2(0, 0, 896, 960)

var _scene: Node2D
var _saved_play_rect: Rect2


func before_test() -> void:
  _scene = auto_free(Node2D.new())
  add_child(_scene)

  # ヘッドレスのビューポートは 64x64 のため PlayArea が幅の負な矩形
  # Rect2(0, 0, -320, 64) を返し、バウンド判定が成立しない。
  # 実機相当の矩形に差し替えてから検証する。
  _saved_play_rect = PlayArea.get_play_rect()
  PlayArea._play_rect = PLAY_RECT


func after_test() -> void:
  PlayArea._play_rect = _saved_play_rect


func _make_config(follows: bool, bounce: float = BOUNCE_FACTOR) -> BulletMovementConfig:
  var cfg := BulletMovementConfig.new()
  cfg.movement_type = BulletMovementConfig.MovementType.GRAVITY
  cfg.initial_speed = INITIAL_SPEED
  cfg.gravity_strength = GRAVITY_STRENGTH
  cfg.gravity_direction = Vector2(0, 1)
  cfg.gravity_follows_direction = follows
  cfg.air_resistance = 0.0
  cfg.bounce_factor = bounce
  cfg.max_bounces = 0
  cfg.rotation_mode = BulletMovementConfig.RotationMode.FIXED
  return cfg


func _make_bullet(dir: Vector2, cfg: BulletMovementConfig, pos := Vector2(448, 748)) -> Node2D:
  var bullet: Node2D = auto_free(load(BULLET_SCENE).instantiate())
  _scene.add_child(bullet)
  # エンジンの _process と手動駆動が二重に走らないよう止める
  bullet.set_process(false)
  bullet.global_position = pos
  bullet.direction = dir
  bullet.apply_movement_config(cfg)
  return bullet


func _step(bullet: Node2D, frames: int) -> void:
  """UniversalBullet._process() と同じ順序で1フレーム進める。
  GRAVITY は speed = 0 なので ProjectileBullet 側の移動は発生しない。"""
  for _i in frames:
    bullet._update_advanced_movement(DT)
    if bullet.movement_config.bounce_factor > 0:
      bullet._handle_boundary_bounce()


func _step_until_bounce(bullet: Node2D, max_frames: int = 600) -> int:
  """次の反射が起きるまでフレームを進め、要したフレーム数を返す。

  到達時刻を決め打ちするとバウンド後の往復のどこを見ているか不定になるため、
  _bounce_count の増加で反射の瞬間を捕まえる。
  """
  var start: int = bullet._bounce_count
  var frames := 0
  while bullet._bounce_count == start and frames < max_frames:
    _step(bullet, 1)
    frames += 1
  return frames


# =====================================================================
# 1. フラグ
# =====================================================================


func test_gravity_follows_direction_defaults_to_false() -> void:
  """既定 false。既存のGRAVITY弾の挙動を変えないための前提"""
  var cfg := BulletMovementConfig.new()

  assert_bool(cfg.gravity_follows_direction).is_false()


# =====================================================================
# 2. 重力方向の追従
# =====================================================================


func test_gravity_follows_upward_launch() -> void:
  """上向きに撃つと重力も上向きになる"""
  var bullet := _make_bullet(Vector2(0, -1), _make_config(true))

  assert_vector(bullet._gravity_dir).is_equal_approx(Vector2(0, -1), Vector2(0.001, 0.001))


func test_gravity_follows_downward_launch() -> void:
  """後方発射（下向き）では重力も下向きになる"""
  var bullet := _make_bullet(Vector2(0, 1), _make_config(true))

  assert_vector(bullet._gravity_dir).is_equal_approx(Vector2(0, 1), Vector2(0.001, 0.001))


func test_gravity_follows_uses_sign_only_for_diagonal() -> void:
  """斜め発射でも重力は真上/真下。扇の端(22.5度)でも符号だけを見る"""
  var dir := Vector2(0, -1).rotated(deg_to_rad(22.5))
  var bullet := _make_bullet(dir, _make_config(true))

  assert_vector(bullet._gravity_dir).is_equal_approx(Vector2(0, -1), Vector2(0.001, 0.001))


func test_gravity_follows_falls_back_when_horizontal() -> void:
  """Y成分が0（真横発射）のときは設定値にフォールバックする"""
  var cfg := _make_config(true)
  cfg.gravity_direction = Vector2(0, 1)
  var bullet := _make_bullet(Vector2(1, 0), cfg)

  assert_vector(bullet._gravity_dir).is_equal_approx(Vector2(0, 1), Vector2(0.001, 0.001))


func test_upward_bullet_accelerates_upward() -> void:
  """上撃ちの弾は上方向に加速し続ける（放物線を描かない）"""
  var bullet := _make_bullet(Vector2(0, -1), _make_config(true))
  var v0: float = bullet._velocity.y

  _step(bullet, 30)  # 0.5秒

  # 上向き＝Yが負の方向に増速する
  assert_float(bullet._velocity.y).is_less(v0)
  assert_float(bullet._velocity.y).is_equal_approx(v0 - GRAVITY_STRENGTH * 0.5, 15.0)


# =====================================================================
# 3. 共有サブリソースを書き換えない
# =====================================================================


func test_shared_config_is_not_mutated() -> void:
  """同じ movement_config を共有する2発が互いの重力方向を壊さないこと。
  パターン内のサブリソースは全弾・全個体で共有されるため、
  弾ごとの値は _gravity_dir にコピーして持つ必要がある。"""
  var shared := _make_config(true)

  var up := _make_bullet(Vector2(0, -1), shared)
  var down := _make_bullet(Vector2(0, 1), shared, Vector2(448, 200))

  assert_vector(up._gravity_dir).is_equal_approx(Vector2(0, -1), Vector2(0.001, 0.001))
  assert_vector(down._gravity_dir).is_equal_approx(Vector2(0, 1), Vector2(0.001, 0.001))
  # 共有リソース自体は書き換わっていない
  assert_vector(shared.gravity_direction).is_equal_approx(Vector2(0, 1), Vector2(0.001, 0.001))


# =====================================================================
# 4-5. バウンド
# =====================================================================


func test_does_not_stick_to_wall() -> void:
  """奥の壁に張り付かないこと。

  Step1 の修正前は _handle_boundary_bounce() が _velocity だけを反転し、
  direction * speed の等速成分が壁向きに残るため弾が壁に貼り付いていた。
  speed = 0 に一本化したことで跳ね返りが正しく効く。
  """
  var bullet := _make_bullet(Vector2(0, -1), _make_config(true))

  var frames := _step_until_bounce(bullet)
  assert_int(frames).override_failure_message("上端に到達しなかった").is_less(600)

  # 反射時は境界内側のマージン位置にクランプされる
  assert_float(bullet.global_position.y).is_equal_approx(PLAY_RECT.position.y + 4.0, 0.001)
  # 反射直後は下向き（Yが正）の速度を持つ
  assert_float(bullet._velocity.y).is_greater(0.0)

  # 以降、壁から実際に離れていく（張り付かない）
  var y_at_wall: float = bullet.global_position.y
  _step(bullet, 20)
  assert_float(bullet.global_position.y).is_greater(y_at_wall + 20.0)


func test_reaches_wall_at_predicted_time() -> void:
  """仕様2.1の想定軌道と実装が一致すること。

  プレイヤー初期位置 y=748 から真上へ 250px/s、重力600が上向きなので
  748 = 250t + 300t^2 -> t = 1.22秒 で上端に到達し、
  到達時の縦速度は 250 + 600*1.22 = 982px/s になる。
  """
  var bullet := _make_bullet(Vector2(0, -1), _make_config(true))

  var frames := _step_until_bounce(bullet)
  var elapsed := frames * DT
  # 反射で反転済みなので反発係数で割り戻して到達時の速度を求める
  var impact_speed: float = bullet._velocity.y / BOUNCE_FACTOR

  assert_float(elapsed).is_between(1.15, 1.30)
  assert_float(impact_speed).is_between(950.0, 1010.0)


func test_bounces_on_all_four_edges() -> void:
  """上下左右の4辺すべてで反射すること"""
  var play_rect := PLAY_RECT
  var cases := {
    "top": [Vector2(0, -400), Vector2(448, 20)],
    "bottom": [Vector2(0, 400), Vector2(448, play_rect.end.y - 20)],
    "left": [Vector2(-400, 0), Vector2(20, 480)],
    "right": [Vector2(400, 0), Vector2(play_rect.end.x - 20, 480)],
  }

  for edge in cases:
    var vel: Vector2 = cases[edge][0]
    var pos: Vector2 = cases[edge][1]
    # 重力の影響を受けずに反射だけを見るため gravity_strength = 0
    var cfg := _make_config(false)
    cfg.gravity_strength = 0.0
    var bullet := _make_bullet(vel.normalized(), cfg, pos)
    bullet._velocity = vel  # 速度を直接与える

    _step(bullet, 30)

    # 壁に向かっていた成分の符号が反転している
    var vertical := vel.y != 0.0
    var got := signf(bullet._velocity.y) if vertical else signf(bullet._velocity.x)
    var want := -signf(vel.y) if vertical else -signf(vel.x)
    var msg := "%s edge: velocity did not reverse" % edge
    assert_float(got).override_failure_message(msg).is_equal(want)


func test_bounce_applies_restitution() -> void:
  """反発係数どおりに速度が減衰すること"""
  var cfg := _make_config(false)
  cfg.gravity_strength = 0.0
  var play_rect := PLAY_RECT
  var bullet := _make_bullet(Vector2(0, -1), cfg, Vector2(448, play_rect.position.y + 20))
  bullet._velocity = Vector2(0, -600)

  _step(bullet, 10)

  assert_float(absf(bullet._velocity.y)).is_equal_approx(600.0 * BOUNCE_FACTOR, 1.0)


# =====================================================================
# 6. 既存挙動への非干渉（回帰）
# =====================================================================


func test_flag_off_uses_configured_gravity_direction() -> void:
  """既定 false なら進行方向に関係なく gravity_direction をそのまま使う"""
  var cfg := _make_config(false)
  cfg.gravity_direction = Vector2(0, 1)

  var up := _make_bullet(Vector2(0, -1), cfg)
  var down := _make_bullet(Vector2(0, 1), cfg, Vector2(448, 200))

  assert_vector(up._gravity_dir).is_equal_approx(Vector2(0, 1), Vector2(0.001, 0.001))
  assert_vector(down._gravity_dir).is_equal_approx(Vector2(0, 1), Vector2(0.001, 0.001))


func test_existing_gravity_resources_unchanged() -> void:
  """既存のGRAVITY利用箇所が gravity_follows_direction を有効にしていないこと"""
  var pattern = load("res://resources/attackPatterns/single_shot_circle_gravity.tres")
  var cfg: BulletMovementConfig = pattern.bullet_movement_config

  assert_bool(cfg.gravity_follows_direction).is_false()
  # Step1 の移行で 200 -> 400 になっている（旧軌道の維持）
  assert_float(cfg.initial_speed).is_equal_approx(400.0, 0.001)
  assert_float(cfg.bounce_factor).is_equal_approx(0.0, 0.001)


# =====================================================================
# 7. リソース
# =====================================================================


func test_resource_file_loads() -> void:
  """attackcore_magical_ball.tres がエラーなくロードでき、値が仕様どおり"""
  var core = load("res://resources/data/attackcore_magical_ball.tres")

  assert_object(core).is_not_null()
  assert_str(str(core.id)).is_equal("attackcore_magical_ball")
  assert_float(core.damage_base).is_equal_approx(3.0, 0.001)
  assert_float(core.cooldown_sec_base).is_equal_approx(1.5, 0.001)

  var pattern: AttackPattern = core.attack_pattern
  assert_int(pattern.direction_type).is_equal(AttackPattern.DirectionType.RANDOM)
  assert_float(pattern.angle_spread).is_equal_approx(45.0, 0.001)
  assert_int(pattern.penetration_count).is_equal(2)
  assert_float(pattern.bullet_lifetime).is_equal_approx(5.0, 0.001)
  assert_bool(pattern.persist_offscreen).is_true()

  var cfg: BulletMovementConfig = pattern.bullet_movement_config
  assert_int(cfg.movement_type).is_equal(BulletMovementConfig.MovementType.GRAVITY)
  assert_bool(cfg.gravity_follows_direction).is_true()
  assert_float(cfg.bounce_factor).is_equal_approx(BOUNCE_FACTOR, 0.001)
  assert_int(cfg.max_bounces).is_equal(0)
  # movement_config が speed を上書きするため base_modifiers と一致させる
  assert_float(cfg.initial_speed).is_equal_approx(INITIAL_SPEED, 0.001)
  assert_float(core.base_modifiers.get("bullet_speed", 0.0)).is_equal_approx(INITIAL_SPEED, 0.001)


func test_forced_lifetime_covers_max_retention() -> void:
  """forced_lifetime が残留Lv3適用後の寿命を切り詰めないこと。

  persist_offscreen = true のとき forced_lifetime は画面内でも加算される絶対上限。
  bullet_lifetime より短いと残留エンチャントが無効化される。
  """
  var core = load("res://resources/data/attackcore_magical_ball.tres")
  var pattern: AttackPattern = core.attack_pattern
  var lifetime_lv3: float = pattern.bullet_lifetime * (1.0 + 2.0)  # 残留Lv3 = +200%

  assert_float(lifetime_lv3).is_equal_approx(15.0, 0.001)
  assert_float(pattern.forced_lifetime).is_greater(lifetime_lv3)
