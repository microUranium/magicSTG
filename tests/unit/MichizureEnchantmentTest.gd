# === エンチャント「道連」(fortitude_michizure_damage_add) 機能テスト ===
# テスト対象:
#   1. ティア値・説明文と付与先（不屈の加護のみ）
#   2. 不屈の加護の発動時に、画面内の敵にだけダメージを与える
#   3. 道連が付いていなければダメージを与えない
#   4. 幸運で回数を消費しなかったときも発動する
#   5. ヘビの胴体は頭に置き換え、1 回だけ当てる
#   6. 敵ごとに星のパーティクルが出る
#   7. 大ダメージでもボスのフェーズは一度に 1 つしか進まない（take_burst_damage）
extends GdUnitTestSuite

const FortitudeBlessing := preload("res://scripts/player/FortitudeBlessing.gd")
const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const MICHIZURE_PATH := "res://resources/data/enchantment_michizure.tres"
const FORTITUDE_PATH := "res://resources/data/blessing_fortitude.tres"
const PLAY_RECT := Rect2(0, 0, 1000, 1000)


class MockHpNode:
  extends Node
  signal hp_changed(current_hp: int, max_hp: int)

  var max_hp := 20
  var current_hp := 20

  func take_damage(amount: int = 1) -> void:
    current_hp = maxi(0, current_hp - amount)
    hp_changed.emit(current_hp, max_hp)

  func heal(amount: int = 1) -> void:
    current_hp = mini(max_hp, current_hp + amount)
    hp_changed.emit(current_hp, max_hp)


class MockPlayer:
  extends Node2D

  var hp_node := MockHpNode.new()

  func _ready() -> void:
    add_child(hp_node)

  func set_invincible(_duration_sec: float) -> void:
    pass


class MockEnemy:
  extends Node2D
  var taken := 0
  var hits := 0

  func _ready() -> void:
    add_to_group("enemies")

  func take_burst_damage(amount: int) -> void:
    taken += amount
    hits += 1

  func take_damage(amount: int) -> void:
    take_burst_damage(amount)


## ヘビの胴体の代わり：head_worm_boss を持ち、自分ではダメージを受けない
class MockSegment:
  extends Node2D
  var head_worm_boss: Node

  func _ready() -> void:
    add_to_group("enemies")

  func take_damage(amount: int) -> void:
    head_worm_boss.take_damage(amount)


var _saved_rect: Rect2
var _world: Node2D
var _player: MockPlayer
var _saved_scene: Node


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _saved_scene = get_tree().current_scene
  # パーティクルは current_scene に追加されるため、テスト用の world を current_scene にする
  _world = Node2D.new()
  get_tree().root.add_child(_world)
  get_tree().current_scene = _world
  _player = MockPlayer.new()
  _world.add_child(_player)


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  get_tree().current_scene = _saved_scene
  _world.queue_free()


func _make_blessing(michizure_level: int, extra: Array = []) -> Node:
  var inst := ItemInstance.new(load(FORTITUDE_PATH))
  if michizure_level > 0:
    inst.enchantments[load(MICHIZURE_PATH) as Enchantment] = michizure_level
  for e in extra:
    inst.enchantments[e[0]] = e[1]
  var blessing: Node = FortitudeBlessing.new()
  _world.add_child(blessing)
  blessing.item_inst = inst
  blessing.on_equip(_player)
  return blessing


func _add_enemy(pos: Vector2) -> MockEnemy:
  var enemy := MockEnemy.new()
  _world.add_child(enemy)
  enemy.global_position = pos
  return enemy


func _revive(blessing: Node) -> void:
  _player.hp_node.current_hp = 1
  assert_bool(blessing.process_fatal_damage(_player, 5)).is_true()


func _particle_count() -> int:
  return _world.get_children().filter(func(n): return n is CPUParticles2D).size()


# =====================================================================
# 1. データ
# =====================================================================


func test_enchantment_data() -> void:
  var enchant: Enchantment = load(MICHIZURE_PATH)
  assert_str(str(enchant.id)).is_equal("michizure")
  assert_str(enchant.display_name).is_equal("道連")
  assert_str(enchant.description).is_equal("致命的なダメージを受けた時、画面の敵全体にダメージを与えます。")
  var expected := {1: 150, 2: 450, 3: 1000}
  for level in expected:
    var value := int(enchant.get_modifiers(level)["fortitude_michizure_damage_add"])
    assert_int(value).is_equal(expected[level])


func test_only_fortitude_allows_michizure() -> void:
  var enchant: Enchantment = load(MICHIZURE_PATH)
  for path in DirAccess.get_files_at("res://resources/data"):
    if not (path.begins_with("attackcore_") or path.begins_with("blessing_")):
      continue
    if not path.ends_with(".tres"):
      continue
    var item: ItemBase = load("res://resources/data/" + path)
    var expected := path == "blessing_fortitude.tres"
    assert_bool(item.allows_enchantment(enchant)).override_failure_message(path).is_equal(expected)


# =====================================================================
# 2〜6. 発動
# =====================================================================


func test_revive_damages_only_on_screen_enemies() -> void:
  var blessing := _make_blessing(3)
  var inside := _add_enemy(Vector2(500, 500))
  var outside := _add_enemy(Vector2(500, -100))  # 画面の上にいて、まだ入ってきていない

  _revive(blessing)

  assert_int(inside.taken).is_equal(1000)
  assert_int(outside.taken).is_equal(0)


func test_damage_per_level() -> void:
  var expected := {1: 150, 2: 450, 3: 1000}
  for level in expected:
    var blessing := _make_blessing(level)
    var enemy := _add_enemy(Vector2(500, 500))
    _revive(blessing)
    assert_int(enemy.taken).override_failure_message("Lv%d" % level).is_equal(expected[level])
    enemy.free()
    blessing.free()


func test_no_damage_without_enchantment() -> void:
  var blessing := _make_blessing(0)
  var enemy := _add_enemy(Vector2(500, 500))

  _revive(blessing)

  assert_int(enemy.taken).is_equal(0)
  assert_int(_particle_count()).is_equal(1)  # 復活の演出（自機に集まる星）だけ


func test_triggers_on_free_use() -> void:
  var luck := Enchantment.new()
  var tier := EnchantmentTier.new()
  tier.level = 1
  tier.modifiers = {"blessing_free_use_chance_pct": 1.0}
  luck.tiers = [tier]
  var blessing := _make_blessing(1, [[luck, 1]])
  var enemy := _add_enemy(Vector2(500, 500))

  _revive(blessing)

  assert_int(blessing.get_uses_remaining()).is_equal(1)  # 幸運で回数を消費していない
  assert_int(enemy.taken).is_equal(150)


func test_worm_segments_hit_head_once() -> void:
  var blessing := _make_blessing(1)
  var head := _add_enemy(Vector2(500, 500))
  for i in 3:
    var seg := MockSegment.new()
    seg.head_worm_boss = head
    _world.add_child(seg)
    seg.global_position = Vector2(500, 550 + i * 40)

  _revive(blessing)

  assert_int(head.hits).is_equal(1)
  assert_int(head.taken).is_equal(150)


func test_particles_spawn_per_on_screen_enemy() -> void:
  var blessing := _make_blessing(1)
  _add_enemy(Vector2(100, 100))
  _add_enemy(Vector2(800, 300))
  _add_enemy(Vector2(500, -100))  # 画面外：出ない

  _revive(blessing)

  assert_int(_particle_count()).is_equal(1 + 2)  # 復活の演出 + 画面内の敵 2 体


# =====================================================================
# 7. ボスのフェーズ
# =====================================================================


func _spawn_boss(path: String) -> EnemyBase:
  var boss: EnemyBase = (load(path) as PackedScene).instantiate()
  boss.get_node("EnemyAI").skip_dialogue = true
  boss.destroy_particles_scene = null
  _world.add_child(boss)
  await await_idle_frame()
  return boss


func test_burst_damage_kills_normal_enemy() -> void:
  var enemy: EnemyBase = (load("res://scenes/enemy/enemy_b.tscn") as PackedScene).instantiate()
  enemy.destroy_particles_scene = null
  _world.add_child(enemy)

  enemy.take_burst_damage(100000)

  assert_int(enemy.get_burst_hp_floor()).is_equal(0)
  assert_bool(enemy._is_dead).is_true()


func test_phase_floor_helper() -> void:
  var enemy: EnemyBase = (load("res://scenes/enemy/enemy_b.tscn") as PackedScene).instantiate()
  _world.add_child(enemy)
  var hp = enemy.get_node("HpNode")
  hp.max_hp = 1000
  var ratios := {1: 0.8, 3: 0.4, 5: 0.05}

  assert_int(enemy.phase_burst_hp_floor(0, ratios)).is_equal(800)
  assert_int(enemy.phase_burst_hp_floor(1, ratios)).is_equal(800)
  assert_int(enemy.phase_burst_hp_floor(2, ratios)).is_equal(400)  # 会話などを挟んでも先の境目を飛ばさない
  assert_int(enemy.phase_burst_hp_floor(5, ratios)).is_equal(50)
  assert_int(enemy.phase_burst_hp_floor(6, ratios)).is_equal(0)


## skip_dialogue のため、境目を越えた直後の会話フェーズ（2, 4）は自動で次の戦闘フェーズへ進む。
## HP が境目ちょうどで止まっていれば、その先の境目は飛ばしていない。
func test_doll_advances_one_phase_per_burst() -> void:
  var boss = await _spawn_boss("res://scenes/enemy/enemy_boss_doll.tscn")
  var hp = boss.get_node("HpNode")
  var ai = boss.ai
  var max_hp: int = hp.max_hp

  ai._phase_idx = 1
  boss.take_burst_damage(100000)
  assert_int(hp.current_hp).is_equal(floori(max_hp * 0.8))
  assert_int(ai._phase_idx).is_between(2, 3)

  ai._phase_idx = 3
  boss.take_burst_damage(100000)
  assert_int(hp.current_hp).is_equal(floori(max_hp * 0.4))
  assert_int(ai._phase_idx).is_between(4, 5)

  ai._phase_idx = 5
  boss.take_burst_damage(100000)
  assert_int(hp.current_hp).is_equal(floori(max_hp * 0.05))
  assert_int(ai._phase_idx).is_greater_equal(6)


func test_doll_burst_stops_at_floor_when_already_there() -> void:
  var boss = await _spawn_boss("res://scenes/enemy/enemy_boss_doll.tscn")
  var hp = boss.get_node("HpNode")
  boss.ai._phase_idx = 3
  hp.current_hp = floori(hp.max_hp * 0.4)

  boss.take_burst_damage(100000)

  assert_int(hp.current_hp).is_equal(floori(hp.max_hp * 0.4))


func test_bear_keeps_floor_until_second_form() -> void:
  var boss = await _spawn_boss("res://scenes/enemy/enemy_boss_bear.tscn")
  var hp = boss.get_node("HpNode")
  var max_hp: int = hp.max_hp
  boss.ai._phase_idx = 1

  boss.take_burst_damage(100000)
  assert_int(hp.current_hp).is_equal(floori(max_hp * 0.5))
  assert_bool(boss.ai.get_phase_changable()).is_true()

  # 第2形態に移るまでは、それ以上削れない
  boss.take_burst_damage(100000)
  assert_int(hp.current_hp).is_equal(floori(max_hp * 0.5))

  # 第2形態に入った後は倒せる
  boss.ai._next_phase()
  boss.take_burst_damage(100000)
  assert_bool(boss._is_dead).is_true()


func test_stingray_dies_on_last_phase() -> void:
  var boss = await _spawn_boss("res://scenes/enemy/enemy_boss_stingray.tscn")
  var hp = boss.get_node("HpNode")
  boss.ai._phase_idx = 1

  boss.take_burst_damage(100000)
  assert_int(hp.current_hp).is_equal(floori(hp.max_hp * 0.5))
  assert_int(boss.ai._phase_idx).is_equal(2)

  boss.take_burst_damage(100000)
  assert_bool(boss._is_dead).is_true()
