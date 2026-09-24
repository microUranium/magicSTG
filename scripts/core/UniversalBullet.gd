# UniversalBullet.gd - 汎用弾丸スクリプト
extends "res://scripts/player/ProjectileBullet.gd"
class_name UniversalBullet

# === 視覚設定 ===
@export var bullet_config: BulletVisualConfig
@export var movement_config: BulletMovementConfig

# === 内部コンポーネント ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particles: GPUParticles2D = $GPUParticles2D

# === 内部状態 ===
var _movement_timer: float = 0.0
var _original_speed: float
var _prev_position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _homing_timer: float = 0.0  # 追尾経過時間
var _bounce_count: int = 0  # 反射回数
var _boomerang_returning: bool = false  # ブーメランが帰還フェーズに入ったか
var _gravity_dir: Vector2 = Vector2.DOWN  # この弾に適用する重力方向（弾ごとに確定）
var _afterimage_accum: float = 0.0  # 残像の生成間隔の累積

# === 追尾（エンチャント「追尾」）===
# movement_type とは独立したオーバーレイとして進行方向だけを補正する。
# 曲率（旋回半径）で定義するため、弾速が違っても「一定距離で補正できる横ズレ量」が揃う。
var _homing_radius: float = 0.0  # 旋回半径（px）。0 なら追尾無効
var _homing_distance: float = 0.0  # 追尾が有効な飛行距離（px）
var _homing_lock_angle_deg: float = 60.0  # ロック対象の許容角度（度）
var _homing_max_turn_rate_rad: float = PI  # 角速度上限（ラジアン/秒）
var _homing_relock: bool = true  # ターゲット消失時に再ロックするか
var _homing_target: Node2D = null  # ロック中のターゲット
var _homing_travel: float = 0.0  # 追尾開始からの実移動距離
var _homing_prev_position: Vector2 = Vector2.ZERO

const AFTERIMAGE_SCENE = preload("res://scenes/effects/after_image.tscn")

# 螺旋移動用の内部状態
var _spiral_current_radius: float = 0.0  # 現在の螺旋半径
var _spiral_angle: float = 0.0  # 現在の回転角度（ラジアン）
var _spiral_center: Vector2 = Vector2.ZERO  # 螺旋の中心位置
var _spiral_current_speed: float = 0.0  # 現在の速度（加速・減速用）

# フェード管理
enum FadeState { NONE, FADE_IN, VISIBLE, FADE_OUT }
var _fade_state: FadeState = FadeState.NONE
var _fade_timer: float = 0.0
var _base_color: Color = Color.WHITE  # config.colorの元の値を保持
var _current_alpha: float = 1.0
var _fade_out_start_alpha: float = 1.0  # フェードアウト開始時のアルファ値


func _ready():
  super._ready()
  _original_speed = speed
  apply_visual_config()
  apply_movement_config()


func apply_visual_config(config: BulletVisualConfig = null):
  """視覚設定の適用（修正版）"""
  # 引数で渡された設定を優先
  if config:
    bullet_config = config

  # 設定が存在しない場合は処理をスキップ
  if not bullet_config:
    return

  _apply_visual_settings()


func _apply_visual_settings():
  """実際の視覚設定適用"""
  var config = bullet_config

  # スプライト設定
  if config.texture and sprite:
    sprite.texture = config.texture
  if sprite:
    sprite.scale = Vector2(config.scale, config.scale)
    # フェード用に基本カラーを保存
    _base_color = config.color
    # 初期カラーはフェード初期化後に設定

  # コリジョン設定
  if config.collision_radius > 0 and collision:
    var shape = CircleShape2D.new()
    shape.radius = config.collision_radius
    collision.shape = shape

  # パーティクル設定
  if particles:
    particles.visible = config.enable_particles
    if config.enable_particles and config.particle_material:
      particles.process_material = config.particle_material

  # アニメーション設定
  if config.animation_name and animation_player:
    if animation_player.has_animation(config.animation_name):
      animation_player.play(config.animation_name)

  # 発射音は UniversalAttackCore 側で攻撃単位（同一フレームの一斉発射ごと）に再生する。
  # 弾ごとに再生すると大量発射時に音が重複して音量が増大するため、ここでは再生しない。

  # フェード初期化
  _initialize_fade()


func apply_movement_config(config: BulletMovementConfig = null):
  """移動設定の適用"""
  if config:
    movement_config = config

  if not movement_config:
    return
  speed = movement_config.initial_speed
  _original_speed = speed
  _velocity = direction * speed

  # GRAVITY は移動を _velocity 一本に集約する。
  # ProjectileBullet._process() の `position += direction * speed * delta` と
  # _update_gravity() の `position += _velocity * delta` が二重に加算され、
  # 実効初速が initial_speed の2倍になってしまうため speed を 0 にする。
  # これにより _handle_boundary_bounce() が _velocity を反転させるだけで
  # 縦横とも正しく跳ね返る（等速成分が壁向きに残って張り付く問題も解消する）。
  if movement_config.movement_type == BulletMovementConfig.MovementType.GRAVITY:
    speed = 0.0

  # 重力方向を弾ごとに確定させる。
  # movement_config はパターン内のサブリソースで全弾・全個体に共有されるため、
  # 弾ごとの事情で書き換えると同装備の他個体にも波及する。ここで値をコピーして持つ。
  if movement_config.gravity_follows_direction:
    var vertical_sign := signf(direction.y)
    if vertical_sign != 0.0:
      _gravity_dir = Vector2(0.0, vertical_sign)
    else:
      # 真横発射などY成分が0のときは設定値にフォールバックする
      _gravity_dir = movement_config.gravity_direction
  else:
    _gravity_dir = movement_config.gravity_direction

  # 初期角度の設定（FIXED/SELF_ROTATIONモードの場合）
  if (
    movement_config.rotation_mode == BulletMovementConfig.RotationMode.FIXED
    or movement_config.rotation_mode == BulletMovementConfig.RotationMode.SELF_ROTATION
  ):
    rotation = deg_to_rad(movement_config.initial_rotation)

  # 螺旋移動の初期化
  if movement_config.movement_type == BulletMovementConfig.MovementType.SPIRAL:
    _spiral_center = global_position  # デフォルトは弾の生成位置
    _spiral_current_radius = movement_config.spiral_initial_radius
    _spiral_angle = 0.0
    _spiral_current_speed = movement_config.initial_speed


func set_spiral_center(center_pos: Vector2) -> void:
  """螺旋の中心位置を外部から設定する（RELATIVE_TO_TARGET等で使用）"""
  _spiral_center = center_pos


func _process(delta):
  super._process(delta)

  # フェード更新（FADE_INまたはFADE_OUTの場合のみ）
  if _fade_state == FadeState.FADE_IN or _fade_state == FadeState.FADE_OUT:
    _update_fade(delta)

  if movement_config:
    _update_advanced_movement(delta)

    # 螺旋移動以外で境界反射をチェック
    if (
      movement_config.bounce_factor > 0
      and movement_config.movement_type != BulletMovementConfig.MovementType.SPIRAL
    ):
      _handle_boundary_bounce()

  # 追尾は movement_type と直交するオーバーレイ。移動処理の後に方向だけを補正する。
  _update_homing_overlay(delta)

  # 回転モードに応じて弾を回転
  if movement_config:
    match movement_config.rotation_mode:
      BulletMovementConfig.RotationMode.MOVEMENT_DIRECTION:
        # 移動方向に合わせる
        var _direction = (global_position - _prev_position).normalized()
        if _direction != Vector2.ZERO:
          var rotation_angle = _direction.angle() + PI / 2
          rotation = rotation_angle

      BulletMovementConfig.RotationMode.SELF_ROTATION:
        # 角速度で自転
        rotation += deg_to_rad(movement_config.angular_velocity) * delta

      BulletMovementConfig.RotationMode.FIXED:
        # 回転しない（何もしない）
        pass
  else:
    # デフォルトは移動方向に合わせる
    var _direction = (global_position - _prev_position).normalized()
    if _direction != Vector2.ZERO:
      var rotation_angle = _direction.angle() + PI / 2
      rotation = rotation_angle

  _prev_position = global_position

  # 残像は回転が確定した後に生成する（スプライトの向きをそのまま複製するため）
  _update_afterimage(delta)


func setup_homing(
  correction_px: float,
  distance: float,
  lock_angle_deg: float = 60.0,
  max_turn_rate_deg: float = 180.0,
  relock_on_target_lost: bool = true
) -> void:
  """追尾を有効化し、発射時点のターゲットをロックする。

  correction_px: distance を飛ぶ間に補正できる横ズレ量（px）
  旋回半径 r = distance^2 / (2 * correction_px) で、以後は曲率一定で旋回する。
  角速度は ω = 現在速度 / r となるため、弾速が変わっても曲がり方（軌跡の形）は変わらない。

  呼び出し側は global_position / direction / speed / movement_config を設定した後に呼ぶこと。
  """
  _homing_radius = 0.0
  _homing_target = null

  if correction_px <= 0.0 or distance <= 0.0:
    return

  # SPIRAL / BOOMERANG は direction ではなく独自の座標計算で動くため追尾を適用できない。
  # 無理に方向を書き換えると本来の軌道が壊れるので、ここでは何もしない。
  if movement_config:
    match movement_config.movement_type:
      BulletMovementConfig.MovementType.SPIRAL, BulletMovementConfig.MovementType.BOOMERANG:
        return

  _homing_distance = distance
  _homing_lock_angle_deg = lock_angle_deg
  _homing_max_turn_rate_rad = deg_to_rad(max(0.0, max_turn_rate_deg))
  _homing_relock = relock_on_target_lost
  _homing_radius = distance * distance / (2.0 * correction_px)
  _homing_travel = 0.0
  _homing_prev_position = global_position
  _homing_target = _find_homing_lock_target()


func _homing_is_velocity_driven() -> bool:
  """GRAVITY は direction ではなく _velocity で位置を更新するため扱いを分ける"""
  return (
    movement_config != null
    and movement_config.movement_type == BulletMovementConfig.MovementType.GRAVITY
  )


func _homing_forward() -> Vector2:
  if _homing_is_velocity_driven():
    return _velocity.normalized()
  return direction.normalized()


func _homing_current_speed() -> float:
  if _homing_is_velocity_driven():
    return _velocity.length()
  return speed


func _homing_apply_turn(turn_rad: float) -> void:
  if _homing_is_velocity_driven():
    _velocity = _velocity.rotated(turn_rad)
  else:
    direction = direction.rotated(turn_rad)


func _update_homing_overlay(delta: float) -> void:
  """追尾オーバーレイ：進行方向をロック中のターゲットへ曲率一定で曲げる"""
  if _homing_radius <= 0.0:
    return
  if not is_inside_tree() or is_queued_for_deletion():
    return

  # 追尾区間の終了判定は実移動距離で行う（速度変化・重力の影響を正しく拾うため）
  _homing_travel += global_position.distance_to(_homing_prev_position)
  _homing_prev_position = global_position
  if _homing_travel >= _homing_distance:
    _homing_radius = 0.0
    return

  if not is_instance_valid(_homing_target) or not _homing_target.is_inside_tree():
    _homing_target = null
    if not _homing_relock:
      # 仕様上の既定は「発射時にロック、以後は変更なし」。
      # 再ロックしない設定ではターゲット消失後そのまま直進する。
      _homing_radius = 0.0
      return
    # 撃破済みの敵を追い続けて弾が無駄になるのを防ぐため、
    # 同じ条件（画面内・進行方向前方）で捉え直す。捉えられなければ直進のまま継続する。
    _homing_target = _find_homing_lock_target()
    if not _homing_target:
      return

  var forward := _homing_forward()
  if forward == Vector2.ZERO:
    return
  var to_target: Vector2 = _homing_target.global_position - global_position
  if to_target == Vector2.ZERO:
    return

  var angle_diff := wrapf(to_target.angle() - forward.angle(), -PI, PI)
  # 曲率一定 → 角速度は現在速度に比例する。上限でクランプして低速弾の過剰旋回を防ぐ。
  var turn_rate: float = min(_homing_current_speed() / _homing_radius, _homing_max_turn_rate_rad)
  var max_turn := turn_rate * delta
  _homing_apply_turn(clampf(angle_diff, -max_turn, max_turn))


func _is_targetable(target: Node2D) -> bool:
  """照準対象にできるか。迷彩中のプレイヤーだけが false になる。
  当たり判定（_on_area_entered）はこの判定を通さないため、隠れていても被弾はする。"""
  return TargetService.is_player_targetable() or target != TargetService.get_player()


func _find_homing_lock_target() -> Node2D:
  """ロック対象を検索する。

  条件: target_group に所属 / 画面内 / 撃破処理中でない / 進行方向から一定角度以内。
  その中で最も近いものを選ぶ。
  """
  var tree := get_tree()
  if not tree:
    return null

  var forward := _homing_forward()
  var cos_limit := cos(deg_to_rad(clampf(_homing_lock_angle_deg, 0.0, 180.0)))
  var play_rect := PlayArea.get_play_rect()
  var closest: Node2D = null
  var closest_distance := INF

  for node in tree.get_nodes_in_group(target_group):
    if not (node is Node2D):
      continue
    var target := node as Node2D
    if not is_instance_valid(target) or not target.is_inside_tree():
      continue
    if target.is_queued_for_deletion():
      continue
    if not _is_targetable(target):  # 迷彩中のプレイヤーはロックできない
      continue
    # 撃破処理中の敵はまだグループに残っているのでロック対象から外す
    if "_is_dead" in target and target._is_dead:
      continue
    # 画面外で待機中のスポーン直後の敵を掴まないようにする
    if play_rect.has_area() and not play_rect.has_point(target.global_position):
      continue

    var to_target: Vector2 = target.global_position - global_position
    var distance := to_target.length()
    if distance <= 0.0:
      continue
    # 真横・後方の敵はどれだけ曲げても当たらないので候補から外す
    if forward != Vector2.ZERO and forward.dot(to_target / distance) < cos_limit:
      continue
    if distance < closest_distance:
      closest_distance = distance
      closest = target

  return closest


func _update_afterimage(delta: float) -> void:
  """一定間隔で弾のスプライトを複製した残像を生成する"""
  if not bullet_config or not bullet_config.enable_afterimage:
    return
  if bullet_config.afterimage_interval <= 0.0:
    return

  _afterimage_accum += delta
  if _afterimage_accum < bullet_config.afterimage_interval:
    return

  # 残像は装飾なので1フレームに1枚までとし、積み残しは捨てる。
  # 間隔がフレーム時間より短い場合は自然に毎フレーム1枚になる。
  _afterimage_accum = 0.0
  _spawn_afterimage()


func _spawn_afterimage() -> void:
  if not sprite or not sprite.texture:
    return

  # 弾より寿命が長いため、弾の子ではなくシーンに直接ぶら下げる。
  # テスト環境では current_scene が null になりうるので root にフォールバックする。
  var tree := get_tree()
  if not tree:
    return
  var parent: Node = tree.current_scene if tree.current_scene else tree.root
  if not parent:
    return

  var image := AFTERIMAGE_SCENE.instantiate() as AfterImage
  if not image:
    return

  # lifetime は AfterImage._ready() が tween を張るときに読むため add_child より前に、
  # modulate も tween の開始値になるため前に設定する。
  image.lifetime = bullet_config.afterimage_lifetime
  image.modulate = bullet_config.afterimage_color
  image.texture = sprite.texture
  image.z_index = z_index

  parent.add_child(image)

  # global_* は親の変形を考慮して local へ逆算されるため add_child の後に設定する
  image.global_position = sprite.global_position
  image.global_rotation = sprite.global_rotation
  image.scale = sprite.scale


func _update_advanced_movement(delta: float):
  """高度な移動処理"""
  _movement_timer += delta

  match movement_config.movement_type:
    BulletMovementConfig.MovementType.STRAIGHT:
      # デフォルトの直進（何もしない）
      pass
    BulletMovementConfig.MovementType.DECELERATE:
      _update_deceleration(delta)
    BulletMovementConfig.MovementType.ACCELERATE:
      _update_acceleration(delta)
    BulletMovementConfig.MovementType.SINE_WAVE:
      _update_sine_wave(delta)
    BulletMovementConfig.MovementType.HOMING:
      _update_homing(delta)
    BulletMovementConfig.MovementType.GRAVITY:
      _update_gravity(delta)
    BulletMovementConfig.MovementType.SPIRAL:
      _update_spiral(delta)
    BulletMovementConfig.MovementType.BOOMERANG:
      _update_boomerang(delta)

  # 敵に接触している間は速度を contact_speed に固定する（0 = 無効）。
  # 移動速度と接触中の滞在時間を切り離すための設定。
  # ※ _process() は「super._process()（移動）→ _update_advanced_movement()（速度更新）」
  #    の順なので、接触検知から減速反映までは1フレーム遅れる。
  if movement_config.contact_speed > 0.0 and not _contact_targets.is_empty():
    speed = movement_config.contact_speed


func _update_deceleration(delta: float):
  """減速処理"""
  var decel_rate = movement_config.deceleration_rate
  speed = max(movement_config.min_speed, speed - decel_rate * delta)


func _update_acceleration(delta: float):
  """加速処理"""
  var accel_rate = movement_config.acceleration_rate
  speed = min(movement_config.max_speed, speed + accel_rate * delta)


func _update_sine_wave(delta: float):
  """サイン波軌道"""
  var wave_amplitude = movement_config.wave_amplitude
  var wave_frequency = movement_config.wave_frequency

  var perpendicular = Vector2(-direction.y, direction.x)
  var wave_offset = sin(_movement_timer * wave_frequency) * wave_amplitude

  # 基本的な前進 + サイン波の横移動
  position += direction * speed * delta
  position += perpendicular * wave_offset * delta


func _update_homing(delta: float):
  """追尾処理"""
  # 追尾時間の更新
  _homing_timer += delta

  # 追尾時間が経過した場合は追尾を停止（0の場合は永続的）
  if movement_config.homing_duration > 0 and _homing_timer > movement_config.homing_duration:
    return

  var target = _find_homing_target()
  if target:
    var target_direction = (target.global_position - global_position).normalized()
    var current_angle = direction.angle()
    var target_angle = target_direction.angle()

    # 角度差を計算（-π〜π の範囲に正規化）
    var angle_diff = target_angle - current_angle
    while angle_diff > PI:
      angle_diff -= TAU
    while angle_diff < -PI:
      angle_diff += TAU

    # 最大回転角度を適用
    var max_turn_radians = deg_to_rad(movement_config.max_turn_angle_per_second) * delta
    var actual_turn = clamp(angle_diff, -max_turn_radians, max_turn_radians)

    # 新しい方向を設定
    direction = Vector2.from_angle(current_angle + actual_turn)


func _find_homing_target() -> Node2D:
  """追尾対象を検索"""
  var targets = get_tree().get_nodes_in_group(target_group)
  if targets.is_empty():
    return null

  # 最も近い対象を選択
  var closest_target = null
  var closest_distance = INF

  for target in targets:
    if target is Node2D:
      if not _is_targetable(target):  # 迷彩中のプレイヤーは追尾対象外
        continue
      var distance = global_position.distance_to(target.global_position)
      if distance < closest_distance:
        closest_distance = distance
        closest_target = target
  return closest_target


func _update_gravity(delta: float):
  """重力処理"""
  # 重力による加速度を速度に加算（方向は弾ごとに確定した _gravity_dir を使う）
  _velocity += _gravity_dir * movement_config.gravity_strength * delta

  # 空気抵抗を適用
  if movement_config.air_resistance > 0:
    _velocity *= (1.0 - movement_config.air_resistance * delta)

  # 速度ベースで位置を更新
  var step := _velocity * delta
  position += step

  # GRAVITY は speed = 0 で運用するため ProjectileBullet._process() の
  # `_moving_distance += speed * delta` が伸びない。bullet_range を機能させるため
  # 実移動量をここで積む（射程判定は次フレームに1回遅れる）。
  _moving_distance += step.length()


func _update_boomerang(delta: float):
  """ブーメラン移動処理

  往路：initial_speed から boomerang_outbound_time 秒かけて線形に減速し 0 で停止する。
        往路の到達距離 = initial_speed * boomerang_outbound_time / 2
  復路：毎フレーム進行方向をプレイヤーへ向け直し、boomerang_return_max_speed まで加速する。
        boomerang_catch_radius まで近づいたら回収（爆発を出さずに削除）。

  プレイヤー不在時は向きを維持して直進し、forced_lifetime で消滅する。
  """
  if not _boomerang_returning:
    var outbound_time: float = movement_config.boomerang_outbound_time
    if outbound_time <= 0.0 or _movement_timer >= outbound_time:
      # 停止 → 帰還フェーズへ
      speed = 0.0
      _boomerang_returning = true
    else:
      speed = movement_config.initial_speed * (1.0 - _movement_timer / outbound_time)
    return

  # === 復路 ===
  # 回収判定は帰還フェーズのみで行う。往路の開始時点では弾がプレイヤーの至近距離に
  # あるため、フェーズを問わず判定すると発射直後に回収されてしまう。
  var player := TargetService.get_player()
  if is_instance_valid(player):
    if (
      global_position.distance_to(player.global_position) <= movement_config.boomerang_catch_radius
    ):
      _boomerang_catch()
      return
    direction = (player.global_position - global_position).normalized()

  speed = min(
    movement_config.boomerang_return_max_speed,
    speed + movement_config.boomerang_return_accel * delta
  )


func _boomerang_catch():
  """プレイヤーによる回収。
  「消滅」ではなく「戻ってきた」ことを見せるため、_immediate_removal() を使わず
  爆発エフェクトを出さない。軌跡パーティクルは分離して残す。"""
  _handle_particle_cleanup()
  queue_free()


func _update_spiral(delta: float):
  """螺旋移動処理

  数学的定義:
    x = center_x + radius * cos(angle + phase_offset)
    y = center_y + radius * sin(angle + phase_offset)

  where:
    - radius: 時間経過で増加/減少する半径
    - angle: 回転角度（rotation_speedで変化）
    - phase_offset: 初期角度のオフセット
    - center: 前進方向に移動する中心点
  """
  # === 1. 速度の更新（加速・減速処理） ===
  if movement_config.spiral_acceleration != 0.0:
    _spiral_current_speed += movement_config.spiral_acceleration * delta
    _spiral_current_speed = clamp(
      _spiral_current_speed, movement_config.spiral_min_speed, movement_config.spiral_max_speed
    )
  else:
    _spiral_current_speed = movement_config.initial_speed

  # === 2. 螺旋の中心を前進方向に移動 ===
  _spiral_center += direction * _spiral_current_speed * delta

  # === 3. 半径の更新（広がり/収束） ===
  _spiral_current_radius += movement_config.spiral_radius_growth * delta
  # 半径が負にならないようにクランプ（内向き螺旋の終端処理）
  # _spiral_current_radius = max(0.0, _spiral_current_radius)

  # === 4. 回転角度の更新（回転方向を考慮） ===
  var rotation_direction = 1.0 if movement_config.spiral_clockwise else -1.0
  _spiral_angle += deg_to_rad(movement_config.spiral_rotation_speed) * rotation_direction * delta

  # === 5. 位相オフセットを適用した最終角度 ===
  var total_angle = _spiral_angle + deg_to_rad(movement_config.spiral_phase_offset)

  # === 6. 螺旋座標の計算 ===
  # 螺旋を2D平面（極座標）で計算
  var spiral_offset_local = Vector2(
    _spiral_current_radius * cos(total_angle), _spiral_current_radius * sin(total_angle)
  )

  # === 7. 前進方向に合わせて座標を回転 ===
  # initial_speedが0の場合（中心が固定）、directionによる回転を適用しない
  var spiral_offset = spiral_offset_local
  if _spiral_current_speed != 0.0:
    # 中心が移動する場合のみ、directionの角度を取得して螺旋オフセットを回転
    var direction_angle = direction.angle()
    spiral_offset = spiral_offset_local.rotated(direction_angle)

  # === 8. 最終位置の設定 ===
  global_position = _spiral_center + spiral_offset


func _handle_boundary_bounce():
  """境界でのバウンス処理（反射回数制限付き）"""
  # 反射回数制限チェック
  if movement_config.max_bounces > 0 and _bounce_count >= movement_config.max_bounces:
    return

  var play_rect = PlayArea.get_play_rect()
  var bounced = false
  var bounce_margin = 4.0  # 境界から内側のマージン

  # GRAVITY以外の移動タイプでは、directionベースの反射を使用
  var use_velocity = movement_config.movement_type == BulletMovementConfig.MovementType.GRAVITY

  # 下端での衝突（マージン付き）
  if global_position.y >= play_rect.position.y + play_rect.size.y - bounce_margin:
    global_position.y = play_rect.position.y + play_rect.size.y - bounce_margin
    if use_velocity:
      _velocity.y *= -movement_config.bounce_factor
    else:
      direction.y *= -movement_config.bounce_factor
    bounced = true

  # 上端での衝突（マージン付き）
  if global_position.y <= play_rect.position.y + bounce_margin:
    global_position.y = play_rect.position.y + bounce_margin
    if use_velocity:
      _velocity.y *= -movement_config.bounce_factor
    else:
      direction.y *= -movement_config.bounce_factor
    bounced = true

  # 左端での衝突（マージン付き）
  if global_position.x <= play_rect.position.x + bounce_margin:
    global_position.x = play_rect.position.x + bounce_margin
    if use_velocity:
      _velocity.x *= -movement_config.bounce_factor
    else:
      direction.x *= -movement_config.bounce_factor
    bounced = true

  # 右端での衝突（マージン付き）
  elif global_position.x >= play_rect.position.x + play_rect.size.x - bounce_margin:
    global_position.x = play_rect.position.x + play_rect.size.x - bounce_margin
    if use_velocity:
      _velocity.x *= -movement_config.bounce_factor
    else:
      direction.x *= -movement_config.bounce_factor
    bounced = true

  # 反射が発生した場合はカウンターを増加
  if bounced:
    _bounce_count += 1


func _initialize_fade():
  """フェード機能の初期化"""
  if not bullet_config:
    _fade_state = FadeState.VISIBLE
    _current_alpha = 1.0
    return

  # フェードイン設定の適用
  if bullet_config.fade_in_duration > 0.0:
    _fade_state = FadeState.FADE_IN
    _current_alpha = bullet_config.fade_in_initial_alpha
    _fade_timer = 0.0
  else:
    _fade_state = FadeState.VISIBLE
    _current_alpha = 1.0

  # 初期アルファを適用
  _update_sprite_alpha()


func _update_fade(delta: float):
  """フェード状態の更新"""
  if not bullet_config:
    return

  match _fade_state:
    FadeState.FADE_IN:
      _fade_timer += delta
      var progress = _fade_timer / bullet_config.fade_in_duration

      if progress >= 1.0:
        # フェードイン完了
        _current_alpha = 1.0
        _fade_state = FadeState.VISIBLE
      else:
        # 線形補間: initial_alpha → 1.0
        _current_alpha = lerp(bullet_config.fade_in_initial_alpha, 1.0, progress)

      _update_sprite_alpha()

    FadeState.FADE_OUT:
      _fade_timer += delta
      var progress = _fade_timer / bullet_config.fade_out_duration

      if progress >= 1.0:
        # フェードアウト完了 → 削除
        _finalize_bullet_removal()
      else:
        # 開始時のアルファから0.0へ線形補間
        _current_alpha = lerp(_fade_out_start_alpha, 0.0, progress)
        _update_sprite_alpha()


func _update_sprite_alpha():
  """スプライトのアルファ値を現在のフェード状態に基づいて更新"""
  if sprite:
    sprite.modulate = Color(
      _base_color.r, _base_color.g, _base_color.b, _base_color.a * _current_alpha  # 元のアルファと掛け合わせ
    )


func _immediate_removal():
  """画面外・敵ヒット時の即座削除"""
  _create_explosion_effect()
  _handle_particle_cleanup()
  queue_free()


func _start_fade_out():
  """寿命・射程終了時のフェードアウト開始"""
  if bullet_config and bullet_config.fade_out_duration > 0.0:
    _fade_state = FadeState.FADE_OUT
    _fade_timer = 0.0
    _fade_out_start_alpha = _current_alpha  # 開始時のアルファ値を保存
    # フェードアウト完了まで削除を遅延
  else:
    # フェードアウト無効時は即座削除
    _immediate_removal()


func _finalize_bullet_removal():
  """フェードアウト完了後の最終削除処理"""
  _create_explosion_effect()
  _handle_particle_cleanup()
  queue_free()


func _handle_particle_cleanup():
  """軌跡パーティクルの分離処理"""
  if particles and particles.emitting and bullet_config and bullet_config.enable_particles:
    # 新規パーティクル生成を停止
    particles.emitting = false

    # パーティクルを現在のシーンに分離して残存させる
    var scene_root = get_tree().current_scene
    if scene_root:
      particles.reparent(scene_root)

      # パーティクルのライフタイム後にクリーンアップ
      var cleanup_delay = particles.lifetime + 0.1
      get_tree().create_timer(cleanup_delay, false).timeout.connect(
        func():
          if is_instance_valid(particles):
            particles.queue_free()
      )


func _create_explosion_effect():
  """爆発エフェクトの生成"""
  if bullet_config and bullet_config.explosion_config:
    ExplosionFactory.create_explosion(bullet_config.explosion_config, global_position, target_group)
