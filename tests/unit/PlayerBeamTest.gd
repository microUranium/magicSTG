# === プレイヤー用ビーム（scenes/attackCores/player/beam.tscn）のテスト ===
# BeamCoreTest はスタブのビームを使うため、本物のビームと UniversalAttackCore の
# 呼び出し方の食い違い（initialize の引数の数）を検出できなかった。ここでは本物のシーンで確認する。
extends GdUnitTestSuite

const PLAYER_BEAM_SCENE := "res://scenes/attackCores/player/beam.tscn"


func _initialize_arg_count(script: Script) -> int:
  for m in script.get_script_method_list():
    if m.name == "initialize":
      return m.args.size()
  return -1


func test_initialize_accepts_offset_argument() -> void:
  """UniversalAttackCore は initialize(owner, damage, direction, beam_offset) の4引数で呼ぶ"""
  var beam: Node = auto_free(load(PLAYER_BEAM_SCENE).instantiate())
  assert_int(_initialize_arg_count(beam.get_script())).is_greater_equal(4)


func test_initialize_with_core_arguments() -> void:
  var owner_actor: Node2D = auto_free(Node2D.new())
  add_child(owner_actor)
  owner_actor.global_position = Vector2(200, 300)
  var beam: Node2D = auto_free(load(PLAYER_BEAM_SCENE).instantiate())
  add_child(beam)

  # UniversalAttackCore._execute_beam と同じ引数（プレイヤー用パターンの beam_offset は既定値 (0, 50)）
  beam.initialize(owner_actor, 7, Vector2.UP, Vector2(0, 50))
  beam._process(0.0)

  assert_int(beam.damage).is_equal(7)
  assert_object(beam.owner_node).is_same(owner_actor)
  assert_float(beam.rotation).is_equal_approx(0.0, 0.0001)  # 上向き
  # beam_offset は使わず、精霊の位置にそのまま追従する
  assert_vector(beam.global_position).is_equal(Vector2(200, 300))


# --- 当たり判定 ---------------------------------------------------------


class DamageCounterEnemy:
  extends Area2D
  var taken := 0

  func take_damage(amount: int) -> void:
    taken += amount


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


func _make_enemy(pos: Vector2) -> DamageCounterEnemy:
  var enemy := DamageCounterEnemy.new()
  enemy.add_to_group("enemies")
  return _place_area(enemy, pos, 3) as DamageCounterEnemy


func _make_bullet(pos: Vector2) -> Area2D:
  return _place_area(Area2D.new(), pos, 2, 8.0)


## 精霊 (200, 900) から真上に撃つビームを作り、物理空間に図形が登録されるまで待つ
func _fire_beam_up() -> Node2D:
  var owner_actor: Node2D = auto_free(Node2D.new())
  add_child(owner_actor)
  owner_actor.global_position = Vector2(200, 900)
  var beam: Node2D = auto_free(load(PLAYER_BEAM_SCENE).instantiate())
  add_child(beam)
  beam.initialize(owner_actor, 3, Vector2.UP)
  beam.dmg_timer.stop()  # ダメージはテストから手動で発生させる
  await get_tree().physics_frame
  await get_tree().physics_frame
  beam._process(0.0)
  return beam


func test_beam_hits_enemy_behind_bullet() -> void:
  """ビームと敵の間を弾が横切っていても、奥の敵に当たり続ける"""
  var enemy := _make_enemy(Vector2(200, 400))
  _make_bullet(Vector2(200, 700))  # 精霊と敵の間
  var beam := await _fire_beam_up()

  assert_object(beam._hit_enemy).is_same(enemy)
  # ビームは敵の手前（円の下端 y=416 付近）で止まる
  assert_float(beam.ninepatch.size.y).is_equal_approx(900.0 - 416.0, 1.0)

  beam._on_damage_tick()
  assert_int(enemy.taken).is_equal(3)


func test_beam_passes_through_when_only_bullets() -> void:
  _make_bullet(Vector2(200, 700))
  var beam := await _fire_beam_up()

  assert_object(beam._hit_enemy).is_null()
  assert_float(beam.ninepatch.size.y).is_equal_approx(beam.desired_length, 0.01)


## --- 加護の与ダメージ補正 -------------------------------------------------


## 弾と同じく BlessingContainer.process_outgoing_damage() を通ることを確認するためのスタブ
class StubContainer:
  extends RefCounted
  var bonus_damage := 0

  func process_outgoing_damage(_enemy, base_damage: int, _ctx := {}) -> int:
    return base_damage + bonus_damage


class StubPlayer:
  extends Node2D
  var blessing_container := StubContainer.new()


func _register_player_with_bonus(bonus_damage: int) -> void:
  var player: StubPlayer = auto_free(StubPlayer.new())
  add_child(player)
  player.blessing_container.bonus_damage = bonus_damage
  TargetService.register_player(player)


func after_test() -> void:
  TargetService.unregister_player()


func _deal_tick(beam: Node, enemy: Node) -> void:
  if not enemy.is_in_group("enemies"):
    enemy.add_to_group("enemies")
  beam._hit_enemy = enemy
  beam._on_damage_tick()


func _make_idle_beam(damage: int) -> Node2D:
  var beam: Node2D = auto_free(load(PLAYER_BEAM_SCENE).instantiate())
  add_child(beam)
  beam.dmg_timer.stop()
  beam.damage = damage
  return beam


func test_damage_applies_blessing_bonus() -> void:
  _register_player_with_bonus(2)
  var beam := _make_idle_beam(1)
  var enemy: DamageCounterEnemy = auto_free(DamageCounterEnemy.new())

  _deal_tick(beam, enemy)

  assert_int(enemy.taken).is_equal(3)  # 1 + 加護の補正 2


func test_damage_without_player_is_base_damage() -> void:
  var beam := _make_idle_beam(1)
  var enemy: DamageCounterEnemy = auto_free(DamageCounterEnemy.new())

  _deal_tick(beam, enemy)

  assert_int(enemy.taken).is_equal(1)


func test_beam_hits_nearest_enemy() -> void:
  var far_enemy := _make_enemy(Vector2(200, 200))
  var near_enemy := _make_enemy(Vector2(200, 500))
  var beam := await _fire_beam_up()

  assert_object(beam._hit_enemy).is_same(near_enemy)
  beam._on_damage_tick()
  assert_int(near_enemy.taken).is_equal(3)
  assert_int(far_enemy.taken).is_equal(0)
