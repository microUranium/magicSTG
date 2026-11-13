# === 敵のビーム（scenes/attackCores/enemy/enemy_beam.tscn = UniversalBeam）のテスト ===
# テスト対象:
#   1. 下向きのビームが自機で止まり、自機にダメージを与える
#   2. 発射元とのあいだにいる敵（相手以外）は読み飛ばして自機に当たる
#   3. 自機がいなければ最大長まで伸び、誰にもダメージを与えない
#   4. シェーダーのコマ送り時間は _process でだけ進み（ポーズ中は止まる）、マテリアルはビームごとに別
extends GdUnitTestSuite

const ENEMY_BEAM_SCENE := "res://scenes/attackCores/enemy/enemy_beam.tscn"


class DamageCounter:
  extends Area2D
  var taken := 0

  func take_damage(amount: int) -> void:
    taken += amount


## 当たり判定を持つ Area2D を置く。layer 1 = 自機、layer 3 = 敵（レイヤー1+2）
func _place_area(area: Area2D, pos: Vector2, layer: int, group: String, radius := 16.0) -> Area2D:
  var col := CollisionShape2D.new()
  var circle := CircleShape2D.new()
  circle.radius = radius
  col.shape = circle
  area.add_child(col)
  area.collision_layer = layer
  area.collision_mask = 0
  area.add_to_group(group)
  add_child(area)
  auto_free(area)
  area.global_position = pos
  return area


func _make_beam() -> UniversalBeam:
  var beam: UniversalBeam = auto_free(load(ENEMY_BEAM_SCENE).instantiate())
  add_child(beam)
  beam.dmg_timer.stop()  # ダメージはテストから手動で発生させる
  return beam


## 敵 (200, 100) から下向きに撃つ（オフセット (0, 50) でビームの根元は (200, 150)）
func _fire_down(damage := 2) -> UniversalBeam:
  var shooter: Node2D = auto_free(Node2D.new())
  add_child(shooter)
  shooter.global_position = Vector2(200, 100)
  var beam := _make_beam()
  beam.initialize(shooter, damage, Vector2.DOWN, Vector2(0, 50))
  await get_tree().physics_frame
  await get_tree().physics_frame
  beam._process(0.0)
  return beam


func test_enemy_beam_stops_at_player_and_damages() -> void:
  var player := _place_area(DamageCounter.new(), Vector2(200, 600), 1, "players") as DamageCounter
  var beam := await _fire_down()

  assert_array(beam._hits).contains_exactly([player])
  # 根元 y=150 から自機の円の上端 y=584 まで
  assert_float(beam.ninepatch.size.y).is_equal_approx(584.0 - 150.0, 1.0)

  beam._on_damage_tick()
  assert_int(player.taken).is_equal(2)


func test_enemy_beam_skips_other_enemies() -> void:
  var other_enemy := (
    _place_area(DamageCounter.new(), Vector2(200, 300), 3, "enemies") as DamageCounter
  )
  var player := _place_area(DamageCounter.new(), Vector2(200, 600), 1, "players") as DamageCounter
  var beam := await _fire_down()

  assert_array(beam._hits).contains_exactly([player])
  beam._on_damage_tick()
  assert_int(player.taken).is_equal(2)
  assert_int(other_enemy.taken).is_equal(0)


func test_enemy_beam_full_length_without_player() -> void:
  var beam := await _fire_down()

  assert_array(beam._hits).is_empty()
  assert_float(beam.ninepatch.size.y).is_equal_approx(beam.desired_length, 0.01)


func test_animation_time_advances_only_in_process() -> void:
  var beam := _make_beam()
  var material := beam.ninepatch.material as ShaderMaterial
  var before: float = material.get_shader_parameter("anim_time")

  beam._advance_animation(0.25)

  var after: float = material.get_shader_parameter("anim_time")
  assert_float(after - before).is_equal_approx(0.25, 0.0001)


func test_each_beam_has_own_material() -> void:
  var beam_a := _make_beam()
  var beam_b := _make_beam()
  assert_object(beam_a.ninepatch.material).is_not_same(beam_b.ninepatch.material)

  beam_a._advance_animation(1.0)

  var time_b: float = (beam_b.ninepatch.material as ShaderMaterial).get_shader_parameter(
    "anim_time"
  )
  assert_float(time_b).is_equal_approx(0.0, 0.0001)
