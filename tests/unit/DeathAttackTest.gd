# === 撃破時の攻撃（EnemyBase.death_attack_slot）と grimoire_strong の撃破時のダメージフィールドのテスト ===
# テスト対象:
#   1. grimoire_strong を倒すと、その位置にダメージフィールドが残る（設定は撃破時の攻撃パターンから読む）
#   2. 撃破時の爆発はパーティクルを出さない（ExplosionConfig.enable_particles = false）
#   3. 撃破時の攻撃は、倒されるまで撃たない
#   4. ダメージ0の弾は当たらずにすり抜ける（0 ダメージの被弾として加護の処理を動かさない）
#   5. ExplosionConfig.enable_particles の初期値は true（既存の爆発は変わらない）
extends GdUnitTestSuite

const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 896)
const GRIMOIRE_STRONG := preload("res://scenes/enemy/enemy_grimoire_strong.tscn")
const DAMAGE_FIELD := preload("res://scripts/effects/DamageField.gd")
const BULLET := preload("res://scenes/bullets/universal_bullet.tscn")


class DamageCounter:
  extends Area2D
  var taken := 0
  var hits := 0

  func take_damage(amount: int) -> void:
    taken += amount
    hits += 1


var _saved_rect: Rect2
var _saved_scene: Node
var _saved_player: Node2D
var _world: Node2D
var _player: Node2D


func before_test() -> void:
  # 画面外で消えた弾はフィールドを出さないため、テスト中はプレイエリアを設定しておく
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _saved_scene = get_tree().current_scene
  _world = Node2D.new()
  get_tree().root.add_child(_world)
  get_tree().current_scene = _world
  TargetService.set_bullet_parent(_world)
  _saved_player = TargetService.get_player()
  _player = Node2D.new()
  _world.add_child(_player)
  _player.global_position = Vector2(448, 800)
  TargetService.register_player(_player)


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  if is_instance_valid(_saved_player):
    TargetService.register_player(_saved_player)
  else:
    TargetService.unregister_player()
  TargetService.set_bullet_parent(null)
  get_tree().current_scene = _saved_scene
  _world.free()


func _children_with_script(script: Script) -> Array:
  return _world.get_children().filter(
    func(n): return n.get_script() == script and not n.is_queued_for_deletion()
  )


func _spawn_grimoire(pos: Vector2) -> Node2D:
  var g: Node2D = GRIMOIRE_STRONG.instantiate()
  g.destroy_particles_scene = null
  _world.add_child(g)
  g.global_position = pos
  await await_idle_frame()  # スロットがコアを生成するのを待つ
  return g


func _death_field_config(g: Node) -> Resource:
  var pattern: AttackPattern = g.death_attack_slot.attack_pattern
  return pattern.bullet_visual_config.explosion_config.damage_field


func test_grimoire_strong_leaves_damage_field_on_death() -> void:
  var g := await _spawn_grimoire(Vector2(448, 300))
  var field_config := _death_field_config(g)
  var death_pos := g.global_position

  g.get_node("HpNode").take_damage(g.get_node("HpNode").max_hp)
  # 撃破時に撃った弾はすぐ（寿命切れで）消え、爆発してフィールドを残す
  for i in 5:
    await await_idle_frame()

  var fields := _children_with_script(DAMAGE_FIELD)
  assert_int(fields.size()).is_equal(1)
  assert_vector(fields[0].global_position).is_equal_approx(death_pos, Vector2(1, 1))
  assert_object(fields[0].config).is_same(field_config)
  assert_str(fields[0].target_group).is_equal("players")


func test_death_explosion_has_no_particles_and_no_damage() -> void:
  var g := await _spawn_grimoire(Vector2(448, 300))
  var explosion: ExplosionConfig = (
    g.death_attack_slot.attack_pattern.bullet_visual_config.explosion_config
  )
  assert_bool(explosion.enable_particles).is_false()
  assert_int(explosion.explosion_damage).is_equal(0)
  assert_int(g.death_attack_slot.attack_pattern.damage).is_equal(0)

  g.get_node("HpNode").take_damage(g.get_node("HpNode").max_hp)
  for i in 3:
    await await_idle_frame()

  var effects := _world.get_children().filter(func(n): return n is ExplosionEffect)
  assert_int(effects.size()).is_greater(0)
  for e in effects:
    assert_bool(e.particles.visible).is_false()
    assert_bool(e.particles.emitting).is_false()


func test_death_attack_not_fired_before_death() -> void:
  await _spawn_grimoire(Vector2(448, 300))

  await await_millis(1500)  # 追加直後のコアの既定クールダウン（1秒）を過ぎても撃たない

  assert_int(_children_with_script(DAMAGE_FIELD).size()).is_equal(0)


func test_zero_damage_bullet_passes_through() -> void:
  var target := DamageCounter.new()
  target.add_to_group("players")
  _world.add_child(target)
  var b: UniversalBullet = BULLET.instantiate()
  _world.add_child(b)
  b.set_process(false)
  b.target_group = "players"
  b.damage = 0

  b._on_area_entered(target)

  assert_int(target.hits).is_equal(0)  # take_damage(0) も呼ばない
  assert_bool(b.is_queued_for_deletion()).is_false()
  b.free()


func test_explosion_particles_enabled_by_default() -> void:
  assert_bool(ExplosionConfig.new().enable_particles).is_true()
