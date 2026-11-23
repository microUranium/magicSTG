# === 爆発の後に残るダメージフィールド（DamageField）のテスト ===
# テスト対象:
#   1. 範囲内の対象に tick_sec ごと（15回/秒）にダメージを与え、範囲外には与えない
#   2. 持続時間が過ぎると当たり判定が止まり、残ったパーティクルが消えてから自分も消える
#   3. 弾の一斉消去（destroy_bullet / destroy_bullets_by_target）で消える
#   4. 爆発の設定に damage_field があれば ExplosionFactory がフィールドを出す（出さない指定もできる）
#   5. 弾が当たる・射程が尽きると爆発でフィールドが出る。一斉消去・画面外で消えたときは出ない
#   6. lantern_b の攻撃が、プレイヤー狙いで1発ずつ撃つ、フィールドを残すファイアボールになっている
extends GdUnitTestSuite

const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 896)
const DAMAGE_FIELD := preload("res://scripts/effects/DamageField.gd")
const DAMAGE_FIELD_CONFIG := preload("res://scripts/core/DamageFieldConfig.gd")
const BULLET := preload("res://scenes/bullets/universal_bullet.tscn")
const LANTERN_B := preload("res://scenes/enemy/enemy_lantern_b.tscn")


class DamageCounter:
  extends Area2D
  var taken := 0
  var hits := 0

  func take_damage(amount: int) -> void:
    taken += amount
    hits += 1


var _saved_rect: Rect2
var _saved_scene: Node
var _world: Node2D


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _saved_scene = get_tree().current_scene
  # 爆発・フィールドは current_scene に追加されるため、テスト用の world を current_scene にする
  _world = Node2D.new()
  get_tree().root.add_child(_world)
  get_tree().current_scene = _world


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  get_tree().current_scene = _saved_scene
  _world.free()


func _field_config() -> Resource:
  var c = DAMAGE_FIELD_CONFIG.new()
  c.radius = 50.0
  c.duration = 2.0
  c.damage = 1
  c.particle_lifetime = 0.3
  return c


func _place_target(pos: Vector2) -> DamageCounter:
  var t := DamageCounter.new()
  var col := CollisionShape2D.new()
  var circle := CircleShape2D.new()
  circle.radius = 8.0
  col.shape = circle
  t.add_child(col)
  t.collision_layer = 1
  t.collision_mask = 0
  t.add_to_group("players")
  _world.add_child(t)
  t.global_position = pos
  return t


func _spawn_field(config: Resource, pos: Vector2) -> Area2D:
  var f = DAMAGE_FIELD.new()
  f.setup(config, pos, "players")
  _world.add_child(f)
  f.set_process(false)  # 時間はテストから手動で進める
  await get_tree().physics_frame
  await get_tree().physics_frame
  return f


func _fields() -> Array:
  return _world.get_children().filter(
    func(n): return n.get_script() == DAMAGE_FIELD and not n.is_queued_for_deletion()
  )


# --- フィールド単体 ---


func test_damages_target_every_tick_inside_radius() -> void:
  var config := _field_config()
  var target := _place_target(Vector2(400, 400))
  var field = await _spawn_field(config, Vector2(400, 400))

  # 1秒分（tick_sec ずつ進める）で 1 / tick_sec 回（15回）当たる
  var ticks := roundi(1.0 / config.tick_sec)
  for i in ticks:
    field._process(config.tick_sec)
  assert_int(target.hits).is_equal(ticks)
  assert_int(target.taken).is_equal(ticks * config.damage)


func test_no_damage_outside_radius() -> void:
  var config := _field_config()
  var target := _place_target(Vector2(400 + config.radius + 30.0, 400))
  var field = await _spawn_field(config, Vector2(400, 400))

  for i in 15:
    field._process(config.tick_sec)
  assert_int(target.hits).is_equal(0)


func test_stops_after_duration_and_frees_after_particles() -> void:
  var config := _field_config()
  var target := _place_target(Vector2(400, 400))
  var field = await _spawn_field(config, Vector2(400, 400))

  # tick_sec を足し合わせると浮動小数の誤差で duration にわずかに届かないことがあるので、1回余分に進める
  var steps := ceili(config.duration / config.tick_sec) + 1
  for i in steps:
    field._process(config.tick_sec)

    # 終了後はダメージを与えない

    # 残ったパーティクルの寿命が過ぎると消える
  assert_bool(field.is_active()).is_false()

  # 終了後はダメージを与えない
  var hits_at_end := target.hits
  for i in 5:
    field._process(config.tick_sec)

    # 残ったパーティクルの寿命が過ぎると消える
  assert_int(target.hits).is_equal(hits_at_end)

  # 残ったパーティクルの寿命が過ぎると消える
  await await_millis(int(config.particle_lifetime * 1000) + 200)
  assert_bool(is_instance_valid(field)).is_false()


func test_draws_translucent_area_circle_that_fades_out() -> void:
  var config := _field_config()
  var field = await _spawn_field(config, Vector2(400, 400))

  # 出ている間は設定どおりの半透明の円（範囲がわかる）
  assert_float(config.area_color.a).is_between(0.01, 0.99)
  assert_object(field.get_area_color()).is_equal(config.area_color)

  # 終了後は円が薄くなって消える
  var steps := ceili(config.duration / config.tick_sec) + 1
  for i in steps:
    field._process(config.tick_sec)
  await await_millis(int(config.particle_lifetime * 500))
  if is_instance_valid(field):
    assert_float(field.get_area_color().a).is_less(config.area_color.a)


func test_particles_shift_from_particle_color_to_end_color() -> void:
  var config := _field_config()
  config.particle_color = Color(1.0, 0.0, 0.0, 1.0)
  config.particle_end_color = Color(1.0, 1.0, 1.0, 1.0)
  var field = await _spawn_field(config, Vector2(400, 400))

  var mat: ParticleProcessMaterial = field._particles.process_material
  var ramp: Gradient = (mat.color_ramp as GradientTexture1D).gradient
  # 寿命の始めは particle_color、終わりは particle_end_color（徐々に白くなる）
  assert_object(ramp.sample(0.0)).is_equal(config.particle_color)
  assert_object(ramp.sample(1.0)).is_equal(config.particle_end_color)
  # 透明度は別に、寿命の終わりに向けて 0 になる
  var fade: Curve = (mat.alpha_curve as CurveTexture).curve
  assert_float(fade.sample(0.0)).is_equal_approx(1.0, 0.01)
  assert_float(fade.sample(1.0)).is_equal_approx(0.0, 0.01)


func test_removed_by_bullet_clear_signals() -> void:
  var config := _field_config()
  var a = await _spawn_field(config, Vector2(200, 200))
  var b = await _spawn_field(config, Vector2(600, 600))

  StageSignals.emit_destroy_bullets_by_target("enemies")  # 自機の弾だけを消す指定では消えない
  await await_idle_frame()
  assert_bool(is_instance_valid(a)).is_true()

  StageSignals.emit_destroy_bullets_by_target("players")
  await await_idle_frame()
  assert_bool(is_instance_valid(a)).is_false()

  var c = await _spawn_field(config, Vector2(400, 400))
  StageSignals.emit_destroy_bullet()
  await await_idle_frame()
  assert_bool(is_instance_valid(c)).is_false()
  assert_bool(is_instance_valid(b)).is_false()


# --- 爆発からの生成 ---


func _explosion_config() -> ExplosionConfig:
  var e := ExplosionConfig.new()
  e.explosion_damage = 5
  e.explosion_radius = 50.0
  e.explosion_duration = 0.1
  e.damage_field = _field_config()
  return e


func test_explosion_spawns_field_unless_suppressed() -> void:
  ExplosionFactory.create_explosion(_explosion_config(), Vector2(300, 300), "players")
  assert_int(_fields().size()).is_equal(1)
  assert_vector(_fields()[0].global_position).is_equal(Vector2(300, 300))
  assert_str(_fields()[0].target_group).is_equal("players")

  ExplosionFactory.create_explosion(_explosion_config(), Vector2(500, 500), "players", false)
  assert_int(_fields().size()).is_equal(1)


func test_explosion_without_field_config_spawns_nothing() -> void:
  var e := _explosion_config()
  e.damage_field = null
  ExplosionFactory.create_explosion(e, Vector2(300, 300), "players")
  assert_int(_fields().size()).is_equal(0)


# --- 弾が消えるときのフィールド ---


func _fireball(pos: Vector2) -> UniversalBullet:
  var visual := BulletVisualConfig.new()
  visual.collision_radius = 8.0
  visual.explosion_config = _explosion_config()
  var b: UniversalBullet = BULLET.instantiate()
  _world.add_child(b)
  b.set_process(false)
  b.target_group = "players"
  b.apply_visual_config(visual)
  b.global_position = pos
  b.direction = Vector2.DOWN
  b.speed = 600.0
  return b


func test_field_spawned_when_bullet_hits_target() -> void:
  var target := _place_target(Vector2(400, 400))
  var b := _fireball(Vector2(400, 400))

  b._on_area_entered(target)

  assert_int(_fields().size()).is_equal(1)


func test_field_spawned_when_bullet_range_runs_out() -> void:
  var b := _fireball(Vector2(400, 400))

  b._start_fade_out()

  assert_int(_fields().size()).is_equal(1)


func test_no_field_when_bullets_cleared() -> void:
  var b := _fireball(Vector2(400, 400))

  b._destroy_bullet()

  assert_int(_fields().size()).is_equal(0)


func test_no_field_when_bullet_leaves_screen() -> void:
  var b := _fireball(Vector2(400, PLAY_RECT.end.y - 2.0))

  b._bullet_process(1.0 / 60.0)  # 1フレームで画面外へ

  assert_bool(b.is_queued_for_deletion()).is_true()
  assert_int(_fields().size()).is_equal(0)


# --- lantern_b の攻撃 ---


func test_lantern_b_fires_aimed_fireball_leaving_damage_field() -> void:
  var lantern: Node = auto_free(LANTERN_B.instantiate())
  var pattern: AttackPattern = lantern.get_node("AttackCoreSlot").attack_pattern

  assert_int(pattern.direction_type).is_equal(AttackPattern.DirectionType.TO_PLAYER)
  assert_int(pattern.bullet_count).is_equal(1)
  assert_float(pattern.bullet_range).is_greater(0.0)  # 当たらなくても射程の終わりで爆発する

  var explosion: ExplosionConfig = pattern.bullet_visual_config.explosion_config
  assert_object(explosion).is_not_null()
  assert_int(explosion.explosion_damage).is_greater(0)
  assert_float(explosion.explosion_radius).is_greater(0.0)
  assert_object(explosion.damage_field).is_not_null()
  assert_object(explosion.damage_field.get_script()).is_same(DAMAGE_FIELD_CONFIG)
