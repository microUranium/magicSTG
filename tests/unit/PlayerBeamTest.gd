# === プレイヤーのビーム（scenes/attackCores/player/beam.tscn = UniversalBeam）のテスト ===
# テスト対象:
#   1. 最初の敵1体にだけ当たり、その手前で止まる
#   2. 手前を弾が横切っても、奥の敵に当たる
#   3. 貫通：貫通数 + 1 体まで当たって最後の敵で止まる／足りなければ最大長まで伸びる
#   4. 下向き（後方発射）でも手前の敵で止まる
#   5. 当たり判定の幅は 4px
#   6. 加護の与ダメージ補正が乗る
#   7. ファクトリー：位置のずらしなし、持続時間はアイテムデータ、貫通エンチャント
#   8. 付与できるエンチャント（速射・貫通）
extends GdUnitTestSuite

const PLAYER_BEAM_SCENE := "res://scenes/attackCores/player/beam.tscn"
const BEAM_ITEM_PATH := "res://resources/data/attackcore_normal_beam.tres"
const PENETRATION_PATH := "res://resources/data/enchantment_penetration_add.tres"
const COOLDOWN_PATH := "res://resources/data/enchantment_cooldown_pct.tres"


class DamageCounterEnemy:
  extends Area2D
  var taken := 0

  func take_damage(amount: int) -> void:
    taken += amount


## 弾と同じく BlessingContainer.process_outgoing_damage() を通ることを確認するためのスタブ
class StubContainer:
  extends RefCounted
  var bonus_damage := 0

  func process_outgoing_damage(_enemy, base_damage: int, _ctx := {}) -> int:
    return base_damage + bonus_damage


class StubPlayer:
  extends Node2D
  var blessing_container := StubContainer.new()


func after_test() -> void:
  TargetService.unregister_player()


## 当たり判定を持つ Area2D を置く。layer 3 = 敵（レイヤー1+2）、layer 2 = 弾
func _place_area(area: Area2D, pos: Vector2, layer: int, radius := 16.0) -> Area2D:
  var col := CollisionShape2D.new()
  var circle := CircleShape2D.new()
  circle.radius = radius
  col.shape = circle
  area.add_child(col)
  area.collision_layer = layer
  area.collision_mask = 0
  add_child(area)
  auto_free(area)
  area.global_position = pos
  return area


func _make_enemy(pos: Vector2, radius := 16.0) -> DamageCounterEnemy:
  var enemy := DamageCounterEnemy.new()
  enemy.add_to_group("enemies")
  return _place_area(enemy, pos, 3, radius) as DamageCounterEnemy


func _make_bullet(pos: Vector2) -> Area2D:
  return _place_area(Area2D.new(), pos, 2, 8.0)


## owner_pos から direction へ撃つビームを作り、物理空間に図形が登録されるまで待つ
func _fire(
  owner_pos := Vector2(200, 900), direction := Vector2.UP, penetration := 0
) -> UniversalBeam:
  var owner_actor: Node2D = auto_free(Node2D.new())
  add_child(owner_actor)
  owner_actor.global_position = owner_pos
  var beam: UniversalBeam = auto_free(load(PLAYER_BEAM_SCENE).instantiate())
  add_child(beam)
  beam.initialize(owner_actor, 3, direction)
  beam.penetration_count = penetration
  beam.dmg_timer.stop()  # ダメージはテストから手動で発生させる
  await get_tree().physics_frame
  await get_tree().physics_frame
  beam._process(0.0)
  return beam


# --- 当たり方 -------------------------------------------------------------


func test_hits_only_nearest_enemy_and_stops_before_it() -> void:
  var far_enemy := _make_enemy(Vector2(200, 200))
  var near_enemy := _make_enemy(Vector2(200, 400))
  var beam := await _fire()

  assert_array(beam._hits).contains_exactly([near_enemy])
  # 精霊 y=900 から手前の敵の円の下端 y=416 まで
  assert_float(beam.ninepatch.size.y).is_equal_approx(900.0 - 416.0, 1.0)

  beam._on_damage_tick()
  assert_int(near_enemy.taken).is_equal(3)
  assert_int(far_enemy.taken).is_equal(0)


func test_hits_enemy_behind_bullet() -> void:
  var enemy := _make_enemy(Vector2(200, 400))
  _make_bullet(Vector2(200, 700))  # 精霊と敵の間
  var beam := await _fire()

  assert_array(beam._hits).contains_exactly([enemy])
  assert_float(beam.ninepatch.size.y).is_equal_approx(900.0 - 416.0, 1.0)


func test_full_length_when_only_bullets() -> void:
  _make_bullet(Vector2(200, 700))
  var beam := await _fire()

  assert_array(beam._hits).is_empty()
  assert_float(beam.ninepatch.size.y).is_equal_approx(beam.desired_length, 0.01)


func test_penetration_hits_next_enemy_and_stops_there() -> void:
  var far_enemy := _make_enemy(Vector2(200, 100))
  var mid_enemy := _make_enemy(Vector2(200, 300))
  var near_enemy := _make_enemy(Vector2(200, 500))
  var beam := await _fire(Vector2(200, 900), Vector2.UP, 1)  # 貫通1 = 2体

  assert_array(beam._hits).contains_exactly([near_enemy, mid_enemy])
  # 2体目（y=300）の円の下端 y=316 で止まる
  assert_float(beam.ninepatch.size.y).is_equal_approx(900.0 - 316.0, 1.0)

  beam._on_damage_tick()
  assert_int(near_enemy.taken).is_equal(3)
  assert_int(mid_enemy.taken).is_equal(3)
  assert_int(far_enemy.taken).is_equal(0)


func test_penetration_with_fewer_enemies_extends_full_length() -> void:
  var enemy := _make_enemy(Vector2(200, 400))
  var beam := await _fire(Vector2(200, 900), Vector2.UP, 2)  # 貫通2 = 3体まで

  assert_array(beam._hits).contains_exactly([enemy])
  assert_float(beam.ninepatch.size.y).is_equal_approx(beam.desired_length, 0.01)


func test_downward_beam_stops_before_enemy() -> void:
  """後方発射（下向き）でも判定が正しい向きを向く"""
  var enemy := _make_enemy(Vector2(200, 600))
  var beam := await _fire(Vector2(200, 100), Vector2.DOWN)

  assert_array(beam._hits).contains_exactly([enemy])
  # 精霊 y=100 から敵の円の上端 y=584 まで
  assert_float(beam.ninepatch.size.y).is_equal_approx(584.0 - 100.0, 1.0)


func test_hit_width_is_4px() -> void:
  # 半径1の敵：帯の半幅 2px + 半径 1px = 中心から 3px 以内なら当たる
  var inside := _make_enemy(Vector2(202.5, 500), 1.0)
  var outside := _make_enemy(Vector2(196.0, 400), 1.0)  # 中心から 4px
  var beam := await _fire(Vector2(200, 900), Vector2.UP, 1)

  assert_array(beam._hits).contains_exactly([inside])
  assert_bool(outside in beam._hits).is_false()


func test_follows_owner_without_offset() -> void:
  var beam := await _fire(Vector2(200, 900))
  assert_vector(beam.global_position).is_equal(Vector2(200, 900))


func test_damage_applies_blessing_bonus() -> void:
  var player: StubPlayer = auto_free(StubPlayer.new())
  add_child(player)
  player.blessing_container.bonus_damage = 2
  TargetService.register_player(player)
  var enemy := _make_enemy(Vector2(200, 400))
  var beam := await _fire()

  beam._on_damage_tick()

  assert_int(enemy.taken).is_equal(5)  # 3 + 加護の補正 2


# --- ファクトリー・エンチャント -----------------------------------------------


func _make_pattern(enchants: Dictionary = {}) -> AttackPattern:
  var inst := ItemInstance.new(load(BEAM_ITEM_PATH))
  for path in enchants:
    inst.add_enchantment(load(path), enchants[path])
  var pattern := PlayerAttackPatternFactory.create_pattern_from_item_instance(inst)
  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, inst)
  return pattern


func test_factory_beam_pattern_has_no_offset() -> void:
  var pattern := _make_pattern()
  assert_int(pattern.pattern_type).is_equal(AttackPattern.PatternType.BEAM)
  assert_vector(pattern.beam_offset).is_equal(Vector2.ZERO)


func test_factory_beam_duration_from_data() -> void:
  assert_float(_make_pattern().beam_duration).is_equal_approx(2.0, 0.0001)


func test_penetration_enchantment_sets_beam_penetration() -> void:
  var expected := {1: 1, 2: 2, 3: 4}
  for level in expected:
    var pattern := _make_pattern({PENETRATION_PATH: level})
    assert_int(pattern.penetration_count).is_equal(expected[level])


func test_beam_allowed_enchantments() -> void:
  var item: ItemBase = load(BEAM_ITEM_PATH)
  for path in [COOLDOWN_PATH, PENETRATION_PATH]:
    assert_bool(item.allows_enchantment(load(path))).override_failure_message(path).is_true()
