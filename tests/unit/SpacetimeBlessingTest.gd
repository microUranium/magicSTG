# === 時界の加護 機能テスト ===
# テスト対象:
#   1. アイテムデータ（基本値・説明文・付与できるエンチャントは持続のみ）
#   2. ゲージ：クールタイム中は溜まり、準備完了で満タン、効果中は減る
#   3. 準備完了でないと発動できない
#   4. 発動時：半径内の敵弾だけを爆発させずに消す（範囲外の敵弾・自弾は残す）
#   5. 結界に入った敵弾は time_scale 0.05、出ると 1.0（自弾は対象外）
#   6. 効果終了時：結界内の敵弾を消し、クールタイムが 0 から始まる
#   7. 一時停止中は発動できず、タイマーも止まる
#   8. 結界は自機についていく
#   9. 持続で効果時間が伸びる
#  10. 背景の演出（反転の強さの移り変わり）
extends GdUnitTestSuite

const SpacetimeBlessing := preload("res://scripts/player/SpacetimeBlessing.gd")
const FIELD_EFFECT := preload("res://scripts/effects/SpacetimeFieldEffect.gd")
const ITEM_PATH := "res://resources/data/blessing_spacetime.tres"
const DURATION_PATH := "res://resources/data/enchantment_blessing_duration_pct.tres"
const AREA_PATH := "res://resources/data/enchantment_blessing_area_pct.tres"
const RECOVER_PATH := "res://resources/data/enchantment_shield_recover_delay_pct.tres"


## 爆発したかを記録するテスト用の弾（敵弾は target_group = "players"）
class StubBullet:
  extends BulletBase
  var exploded := false

  func _create_explosion_effect():
    exploded = true


var _player: Node2D


func before_test() -> void:
  _player = auto_free(Node2D.new())
  add_child(_player)
  _player.global_position = Vector2(400, 400)


func _make_blessing(enchants: Dictionary = {}) -> Node:
  var blessing: Node = auto_free(SpacetimeBlessing.new())
  add_child(blessing)
  var inst := ItemInstance.new(load(ITEM_PATH))
  for path in enchants:
    var enc: Enchantment = load(path)
    inst.enchantments[enc] = enchants[path]
  blessing.item_inst = inst
  blessing.on_equip(_player)
  return blessing


func _make_bullet(pos: Vector2, target_group := "players", layer := 2) -> StubBullet:
  var bullet := StubBullet.new()
  bullet.target_group = target_group
  var col := CollisionShape2D.new()
  var circle := CircleShape2D.new()
  circle.radius = 6.0
  col.shape = circle
  bullet.add_child(col)
  bullet.collision_layer = layer
  bullet.collision_mask = 0
  add_child(bullet)
  auto_free(bullet)
  bullet.global_position = pos
  return bullet


func _physics_frames(n := 2) -> void:
  for _i in n:
    await get_tree().physics_frame


func _ready_blessing(enchants: Dictionary = {}) -> Node:
  var blessing := _make_blessing(enchants)
  blessing._recharge_timer.stop()
  blessing._on_recharged()
  return blessing


# --- データ -------------------------------------------------------------


func test_item_data() -> void:
  var item: BlessingItem = load(ITEM_PATH)
  assert_str(str(item.id)).is_equal("blessing_spacetime")
  assert_str(item.display_name).is_equal("時界の加護")
  assert_str(item.description).is_equal("一定時間、周囲の弾を減速させる結界を展開します。効果終了時、結界内の弾を消滅させます。")
  assert_float(float(item.base_modifiers["blessing_cooldown_sec"])).is_equal_approx(40.0, 0.001)
  assert_float(float(item.base_modifiers["spacetime_duration_sec"])).is_equal_approx(7.0, 0.001)
  assert_float(float(item.base_modifiers["spacetime_radius"])).is_equal_approx(200.0, 0.001)
  assert_bool(item.allows_enchantment(load(DURATION_PATH))).is_true()
  var uses: Enchantment = load("res://resources/data/enchantment_blessing_uses_add.tres")
  assert_bool(item.allows_enchantment(uses)).is_false()


func test_stats_from_data_and_duration_enchantment() -> void:
  var blessing := _make_blessing()
  assert_float(blessing.cooldown_total).is_equal_approx(40.0, 0.001)
  assert_float(blessing.duration_sec).is_equal_approx(7.0, 0.001)
  assert_float(blessing.radius).is_equal_approx(200.0, 0.001)

  var with_duration := _make_blessing({DURATION_PATH: 3})
  assert_float(with_duration.duration_sec).is_equal_approx(14.0, 0.001)  # 7 × (1 + 1.0)


# --- ゲージ・発動条件 -----------------------------------------------------


func test_gauge_fills_during_cooldown_and_is_full_when_ready() -> void:
  var blessing := _make_blessing()
  assert_int(blessing.get_state()).is_equal(blessing.State.COOLING)
  assert_bool(blessing.can_activate()).is_false()

  blessing._recharge_timer.start(10.0)  # 残り 10 秒 / 40 秒
  blessing._process(0.0)
  assert_float(blessing.gauge_current).is_equal_approx(75.0, 0.5)

  blessing._recharge_timer.stop()
  blessing._on_recharged()
  blessing._process(0.0)
  assert_int(blessing.get_state()).is_equal(blessing.State.READY)
  assert_float(blessing.gauge_current).is_equal_approx(100.0, 0.001)


func test_gauge_decreases_while_active() -> void:
  var blessing := _ready_blessing()
  assert_bool(blessing.activate()).is_true()
  assert_bool(blessing.is_active()).is_true()

  blessing._duration_timer.start(3.5)  # 残り 3.5 秒 / 7 秒
  blessing._process(0.0)

  assert_float(blessing.gauge_current).is_equal_approx(50.0, 0.5)
  assert_bool(blessing.activate()).is_false()  # 効果中は発動できない


func test_cannot_activate_while_paused() -> void:
  var blessing := _ready_blessing()
  blessing.set_paused(true)

  assert_bool(blessing.activate()).is_false()
  assert_bool(blessing._recharge_timer.paused).is_true()
  assert_bool(blessing._duration_timer.paused).is_true()


# --- 結界 ---------------------------------------------------------------


func test_activation_vanishes_only_enemy_bullets_in_radius() -> void:
  var inside := _make_bullet(Vector2(400, 300))  # 自機から 100px
  var outside := _make_bullet(Vector2(400, 100))  # 自機から 300px
  var own := _make_bullet(Vector2(400, 300), "enemies")  # 自弾
  var blessing := _ready_blessing()
  await _physics_frames()

  blessing.activate()

  assert_bool(inside.is_queued_for_deletion()).is_true()
  assert_bool(inside.exploded).is_false()  # 爆発させない
  assert_bool(outside.is_queued_for_deletion()).is_false()
  assert_bool(own.is_queued_for_deletion()).is_false()


func test_field_slows_entering_enemy_bullets_and_restores_on_exit() -> void:
  var blessing := _ready_blessing()
  var enemy := _make_bullet(Vector2(400, 0))  # 範囲外から
  var own := _make_bullet(Vector2(400, 0), "enemies")
  blessing.activate()
  await _physics_frames()

  enemy.global_position = Vector2(400, 300)  # 結界に入る
  own.global_position = Vector2(400, 300)
  await _physics_frames()
  assert_float(enemy.time_scale).is_equal_approx(0.05, 0.0001)
  assert_float(own.time_scale).is_equal_approx(1.0, 0.0001)

  enemy.global_position = Vector2(400, 0)  # 結界から出る
  await _physics_frames()
  assert_float(enemy.time_scale).is_equal_approx(1.0, 0.0001)


func test_field_end_vanishes_bullets_inside_and_restarts_cooldown() -> void:
  var blessing := _ready_blessing()
  blessing.activate()
  await _physics_frames()
  var inside := _make_bullet(Vector2(400, 300))
  var outside := _make_bullet(Vector2(400, 0))
  await _physics_frames()
  assert_float(inside.time_scale).is_equal_approx(0.05, 0.0001)

  blessing._end_field()

  assert_bool(inside.is_queued_for_deletion()).is_true()
  assert_bool(inside.exploded).is_false()
  assert_bool(outside.is_queued_for_deletion()).is_false()
  assert_int(blessing.get_state()).is_equal(blessing.State.COOLING)
  assert_float(blessing._recharge_timer.time_left).is_equal_approx(40.0, 0.1)


func test_field_follows_player() -> void:
  var blessing := _ready_blessing()
  blessing.activate()

  _player.global_position = Vector2(100, 700)
  blessing._process(0.0)

  assert_vector(blessing._field.global_position).is_equal(Vector2(100, 700))


# --- 背景の演出 -----------------------------------------------------------


func test_field_effect_inverts_then_restores_outside() -> void:
  var effect: CanvasLayer = auto_free(FIELD_EFFECT.new())
  add_child(effect)
  var mat: ShaderMaterial = effect.get_field_material()

  effect.start(200.0)
  assert_float(float(mat.get_shader_parameter("invert_outside"))).is_equal_approx(1.0, 0.001)
  assert_float(float(mat.get_shader_parameter("invert_inside"))).is_equal_approx(1.0, 0.001)
  assert_int(effect.layer).is_equal(-99)  # 背景のすぐ上

  await get_tree().create_timer(0.7).timeout  # 外側が戻る時間（0.5 秒）を過ぎる
  assert_float(float(mat.get_shader_parameter("invert_outside"))).is_equal_approx(0.0, 0.001)
  assert_float(float(mat.get_shader_parameter("invert_inside"))).is_equal_approx(1.0, 0.001)


func test_field_effect_finish_frees_itself() -> void:
  var effect: CanvasLayer = FIELD_EFFECT.new()
  add_child(effect)
  effect.start(200.0)

  effect.finish()
  await effect.tree_exited

  assert_bool(is_instance_valid(effect) and not effect.is_queued_for_deletion()).is_false()


func test_blessing_scene_from_item_data() -> void:
  """ゲームと同じく、アイテムデータの blessing_scene から作ると時界の加護（キー発動型）になる"""
  var item: BlessingItem = load(ITEM_PATH)
  var blessing: Node = auto_free(item.blessing_scene.instantiate())
  assert_bool(blessing is ActiveBlessingBase).is_true()
  assert_object(blessing.get_script()).is_same(SpacetimeBlessing)


func test_activation_plays_sound() -> void:
  var blessing := _ready_blessing()
  var played := []
  var on_sfx := func(sfx_name, _pos, _db, _pitch): played.append(sfx_name)
  StageSignals.sfx_play_requested.connect(on_sfx)

  blessing.activate()

  StageSignals.sfx_play_requested.disconnect(on_sfx)
  assert_array(played).contains(["activation_blessing_spacetime"])


func test_activation_sound_is_registered_in_catalog() -> void:
  var catalog = load("res://assets/SFX/SFX_Catalog.tres")
  assert_bool(catalog.table.has("activation_blessing_spacetime")).is_true()
  assert_str(catalog.table["activation_blessing_spacetime"].resource_path).is_equal(
    "res://assets/audio/sfx/activation_blessing_spacetime.wav"
  )


# --- 広範・速復 -----------------------------------------------------------


func test_area_enchantment_data() -> void:
  var enchant: Enchantment = load(AREA_PATH)
  assert_str(str(enchant.id)).is_equal("blessing_area_pct")
  assert_str(enchant.display_name).is_equal("広範")
  assert_str(enchant.description).is_equal("効果範囲が広がります。")
  var expected := {1: 0.15, 2: 0.3, 3: 0.8}
  for level in expected:
    var value := float(enchant.get_modifiers(level)["blessing_area_pct"])
    assert_float(value).is_equal_approx(expected[level], 0.0001)


func test_spacetime_allows_duration_area_and_recover() -> void:
  var item: BlessingItem = load(ITEM_PATH)
  for path in [DURATION_PATH, AREA_PATH, RECOVER_PATH]:
    assert_bool(item.allows_enchantment(load(path))).override_failure_message(path).is_true()
  # 広範は時界だけ、速復は障壁にも残る
  var shield: ItemBase = load("res://resources/data/blessing_shield.tres")
  assert_bool(shield.allows_enchantment(load(AREA_PATH))).is_false()
  assert_bool(shield.allows_enchantment(load(RECOVER_PATH))).is_true()


func test_area_enchantment_widens_radius() -> void:
  var expected := {1: 230.0, 2: 260.0, 3: 360.0}
  for level in expected:
    var blessing := _make_blessing({AREA_PATH: level})
    assert_float(blessing.radius).is_equal_approx(expected[level], 0.001)


func test_area_enchantment_widens_vanish_range() -> void:
  var bullet := _make_bullet(Vector2(400, 150))  # 自機から 250px：基本の 200px では範囲外
  var blessing := _ready_blessing({AREA_PATH: 2})  # 260px
  await _physics_frames()

  blessing.activate()

  assert_bool(bullet.is_queued_for_deletion()).is_true()


func test_recover_enchantment_data() -> void:
  var enchant: Enchantment = load(RECOVER_PATH)
  assert_str(str(enchant.id)).is_equal("shield_recover_delay_pct")
  assert_str(enchant.display_name).is_equal("速復")
  assert_str(enchant.description).is_equal("加護の再使用時間を短縮します。")
  var expected := {1: -0.1, 2: -0.2, 3: -0.5}
  for level in expected:
    var mods := enchant.get_modifiers(level)
    assert_float(float(mods["shield_recover_delay_pct"])).is_equal_approx(expected[level], 0.0001)
    assert_float(float(mods["blessing_cooldown_pct"])).is_equal_approx(expected[level], 0.0001)


func test_recover_enchantment_shortens_cooldown() -> void:
  var expected := {1: 36.0, 2: 32.0, 3: 20.0}
  for level in expected:
    var blessing := _make_blessing({RECOVER_PATH: level})
    assert_float(blessing.cooldown_total).is_equal_approx(expected[level], 0.001)
    assert_float(blessing._recharge_timer.time_left).is_equal_approx(expected[level], 0.1)


# --- レイヤー1の敵弾（ゴースト・スパイク・沼の鳥の埋め込みの弾） ---------------------


func test_layer1_enemy_bullets_are_slowed_and_vanished() -> void:
  """敵シーンに埋め込まれた弾はレイヤー未設定（1）。それでも減速し、発動時・終了時に消える"""
  var at_start := _make_bullet(Vector2(400, 300), "players", 1)
  var blessing := _ready_blessing()
  await _physics_frames()

  blessing.activate()
  assert_bool(at_start.is_queued_for_deletion()).is_true()  # 発動時に消える
  await _physics_frames()

  var entering := _make_bullet(Vector2(400, 300), "players", 1)
  await _physics_frames()
  assert_float(entering.time_scale).is_equal_approx(0.05, 0.0001)  # 結界で減速

  blessing._end_field()
  assert_bool(entering.is_queued_for_deletion()).is_true()  # 終了時に消える
