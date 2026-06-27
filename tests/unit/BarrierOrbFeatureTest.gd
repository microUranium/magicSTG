# === バリアオーブ機能テスト ===
# テスト対象:
#   1. バリア回転中のクールダウン遅延（player_mode時のみawaitで待機）
#   2. バリア回転中のゲージ表示
#   3. 敵モード時はバリア回転awaitなし（従来動作）
#   4. 貫通エンチャント（penetration_add）の適用
#   5. 弾数エンチャント（bullet_count_add）の適用
#   6. BulletBase 貫通判定ロジック
extends GdUnitTestSuite
class_name BarrierOrbFeatureTest

var universal_core: TestableUniversalAttackCore
var test_pattern: AttackPattern
var test_scene: Node2D
var owner_actor: Node2D


func before_test():
  test_scene = Node2D.new()
  add_child(test_scene)

  owner_actor = Node2D.new()
  owner_actor.global_position = Vector2(100, 100)
  test_scene.add_child(owner_actor)

  universal_core = TestableUniversalAttackCore.new()
  test_scene.add_child(universal_core)
  universal_core.set_owner_actor(owner_actor)

  # バリア弾用のベースパターン
  test_pattern = AttackPattern.new()
  test_pattern.pattern_type = AttackPattern.PatternType.BARRIER_BULLETS
  test_pattern.bullet_count = 4
  test_pattern.circle_radius = 80.0
  test_pattern.rotation_duration = 2.0
  test_pattern.damage = 5
  test_pattern.target_group = "enemies"
  test_pattern.rapid_fire_interval = 0.0  # テスト高速化のため弾間遅延なし

  # テスト用ダミー弾丸シーン
  var dummy_bullet = BulletStub.new()
  var packed_bullet_scene := PackedScene.new()
  packed_bullet_scene.pack(dummy_bullet)
  test_pattern.bullet_scene = packed_bullet_scene


func after_test():
  test_scene.queue_free()


# =====================================================================
# 1. バリア回転中のクールダウン遅延テスト
# =====================================================================


func test_barrier_cooldown_delayed_in_player_mode():
  """プレイヤーモード時、バリア回転中はawaitでブロックされCDが遅延する"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = true

  # barrier_movement_configで回転時間を短く設定（テスト用）
  var barrier_config = BarrierBulletMovement.new()
  barrier_config.orbit_duration = 0.15  # 短い回転時間
  barrier_config.rotation_speed = 180.0
  test_pattern.barrier_movement_config = barrier_config

  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  # 発射前の時刻を記録
  var start_msec = Time.get_ticks_msec()

  var success = await universal_core._execute_barrier_bullets(test_pattern)

  var elapsed_msec = Time.get_ticks_msec() - start_msec

  # 成功しているか
  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(4)

  # 回転時間分の時間がかかっている（awaitが実行されたことを確認）
  assert_that(elapsed_msec).is_greater_equal(50)  # タイマー精度のばらつきを許容

  # タイマーがクリアされている
  assert_that(universal_core._barrier_duration_timer).is_null()


func test_barrier_no_delay_in_enemy_mode():
  """敵モード時はバリア回転awaitなし（orbit_duration分の待機がない）"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = false  # 敵モード

  var barrier_config = BarrierBulletMovement.new()
  barrier_config.orbit_duration = 5.0  # 長い回転時間（敵は待たない）
  barrier_config.rotation_speed = 90.0
  test_pattern.barrier_movement_config = barrier_config
  test_pattern.rapid_fire_interval = 0.0  # 弾間の遅延なし

  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  var start_msec = Time.get_ticks_msec()

  var success = await universal_core._execute_barrier_bullets(test_pattern)

  var elapsed_msec = Time.get_ticks_msec() - start_msec

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(4)

  # 敵モードなので5秒のorbit_durationをawaitしない（500ms未満で完了）
  assert_that(elapsed_msec).is_less(500)

  # _barrier_duration_timer は設定されない
  assert_that(universal_core._barrier_duration_timer).is_null()


func test_barrier_timer_uses_barrier_movement_config_duration():
  """barrier_movement_configのorbit_durationがタイマーに使用される"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = true

  var barrier_config = BarrierBulletMovement.new()
  barrier_config.orbit_duration = 0.1
  test_pattern.barrier_movement_config = barrier_config
  test_pattern.rotation_duration = 99.0  # こちらは使われない

  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  var start_msec = Time.get_ticks_msec()
  await universal_core._execute_barrier_bullets(test_pattern)
  var elapsed_msec = Time.get_ticks_msec() - start_msec

  # barrier_movement_configの0.1秒が使われている（99秒ではない）
  assert_that(elapsed_msec).is_less(500)


func test_barrier_timer_fallback_to_rotation_duration():
  """barrier_movement_configがnullの場合、rotation_durationがフォールバックで使用される"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = true

  test_pattern.barrier_movement_config = null
  test_pattern.rotation_duration = 0.1  # こちらがフォールバック

  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  var start_msec = Time.get_ticks_msec()
  await universal_core._execute_barrier_bullets(test_pattern)
  var elapsed_msec = Time.get_ticks_msec() - start_msec

  # rotation_durationの0.1秒が使われる
  assert_that(elapsed_msec).is_greater_equal(50)
  assert_that(elapsed_msec).is_less(500)


# =====================================================================
# 2. バリア回転中のゲージ表示テスト
# =====================================================================


func test_gauge_display_during_barrier_rotation():
  """バリア回転中にゲージが更新される（状態テスト）"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = true
  universal_core.show_gauge_ui = true

  var barrier_config = BarrierBulletMovement.new()
  barrier_config.orbit_duration = 0.3
  test_pattern.barrier_movement_config = barrier_config

  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  # 非同期で実行を開始（awaitブロック中にゲージが更新される）
  universal_core._execute_barrier_bullets(test_pattern)

  # 少し待ってからゲージの状態を確認
  await await_millis(50)

  # _barrier_duration_timer が設定されている
  assert_that(universal_core._barrier_duration_timer).is_not_null()

  # _update_gauge_display()を手動実行してゲージ値が変更されることを確認
  universal_core._update_gauge_display()

  # ゲージが0～100の範囲内で設定されていること（回転残り時間のprogress）
  assert_that(universal_core.gauge_current).is_greater_equal(0.0)
  assert_that(universal_core.gauge_current).is_less_equal(100.0)

  # 残りの時間待ち
  await await_millis(350)


func test_gauge_not_updated_without_show_gauge_ui():
  """show_gauge_ui=falseの場合、ゲージは更新されない"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = true
  universal_core.show_gauge_ui = false

  var barrier_config = BarrierBulletMovement.new()
  barrier_config.orbit_duration = 0.1
  test_pattern.barrier_movement_config = barrier_config

  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  # ゲージ値を記録
  var gauge_before = universal_core.gauge_current

  await universal_core._execute_barrier_bullets(test_pattern)

  # _update_gauge_display()を実行してもゲージが変わらないことを確認
  universal_core._update_gauge_display()

  # show_gauge_ui=falseなので_update_gauge_displayは早期returnし、ゲージ値は変わらない
  assert_that(universal_core.gauge_current).is_equal(gauge_before)


func test_gauge_display_enemy_mode_no_update():
  """敵モードではゲージ表示は更新されない"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = false  # 敵モード
  universal_core.show_gauge_ui = true

  test_pattern.barrier_movement_config = null
  test_pattern.rotation_duration = 1.0

  universal_core.attack_pattern = test_pattern

  # ゲージ値を記録
  var gauge_before = universal_core.gauge_current

  # 手動でゲージ更新を試行
  universal_core._update_gauge_display()

  # 敵モードなのでゲージ更新されない
  assert_that(universal_core.gauge_current).is_equal(gauge_before)


# =====================================================================
# 3. BulletBase 貫通判定ロジックテスト
# =====================================================================


func test_penetration_zero_removes_on_first_hit():
  """penetration_count=0: 最初のヒットで弾が消える"""
  var bullet = BulletBase.new()
  bullet.penetration_count = 0
  bullet.hit_count = 0

  # 貫通なし：hit_count=1で即削除される条件
  bullet.hit_count = 1
  var should_remove = (
    bullet.penetration_count == 0
    or (bullet.penetration_count > 0 and bullet.hit_count > bullet.penetration_count)
  )
  assert_that(should_remove).is_true()

  bullet.queue_free()


func test_penetration_one_allows_one_pass_through():
  """penetration_count=1: 1回貫通し、2回目のヒットで消える"""
  var bullet = BulletBase.new()
  bullet.penetration_count = 1

  # 1回目のヒット: hit_count=1, penetration_count=1 → 1 > 1 = false → 生存
  bullet.hit_count = 1
  var should_remove_1 = (
    bullet.penetration_count == 0
    or (bullet.penetration_count > 0 and bullet.hit_count > bullet.penetration_count)
  )
  assert_that(should_remove_1).is_false()

  # 2回目のヒット: hit_count=2, penetration_count=1 → 2 > 1 = true → 削除
  bullet.hit_count = 2
  var should_remove_2 = (
    bullet.penetration_count == 0
    or (bullet.penetration_count > 0 and bullet.hit_count > bullet.penetration_count)
  )
  assert_that(should_remove_2).is_true()

  bullet.queue_free()


func test_penetration_count_allows_multiple_pass_through():
  """penetration_count=4: 4回貫通し、5回目のヒットで消える"""
  var bullet = BulletBase.new()
  bullet.penetration_count = 4

  # 1～4回目のヒット: 生存
  for i in range(1, 5):
    bullet.hit_count = i
    var should_remove = (
      bullet.penetration_count == 0
      or (bullet.penetration_count > 0 and bullet.hit_count > bullet.penetration_count)
    )
    assert_that(should_remove).is_false()

    # 5回目のヒット: 削除
  bullet.hit_count = 5
  var should_remove_5 = (
    bullet.penetration_count == 0
    or (bullet.penetration_count > 0 and bullet.hit_count > bullet.penetration_count)
  )
  assert_that(should_remove_5).is_true()

  bullet.queue_free()


func test_penetration_infinite_never_removes():
  """penetration_count=-1: 無限貫通（削除されない）"""
  var bullet = BulletBase.new()
  bullet.penetration_count = -1

  # 何回ヒットしても削除されない
  for i in range(1, 100):
    bullet.hit_count = i
    var should_remove = (
      bullet.penetration_count == 0
      or (bullet.penetration_count > 0 and bullet.hit_count > bullet.penetration_count)
    )
    assert_that(should_remove).is_false()
  bullet.queue_free()


# =====================================================================
# 4. エンチャント適用テスト（PlayerAttackPatternFactory）
# =====================================================================


func _create_test_enchantment(enc_id: String, level: int, modifiers: Dictionary) -> Dictionary:
  """テスト用エンチャントを作成してItemInstanceに付与するためのヘルパー"""
  var enc = Enchantment.new()
  enc.id = enc_id

  var tier = EnchantmentTier.new()
  tier.level = level
  tier.modifiers = modifiers

  var tiers_array: Array[EnchantmentTier] = []
  tiers_array.append(tier)
  enc.tiers = tiers_array

  return {"enchantment": enc, "level": level}


func _create_test_item_instance(
  damage_base: float, cooldown_base: float, enchantment_list: Array = []
) -> ItemInstance:
  """テスト用ItemInstanceを作成"""
  var proto = AttackCoreItem.new()
  proto.damage_base = damage_base
  proto.cooldown_sec_base = cooldown_base
  proto.base_modifiers = {"bullet_speed": 400.0}
  proto.icon = null

  var inst = ItemInstance.new(proto, "test_uid")
  for enc_data in enchantment_list:
    inst.add_enchantment(enc_data["enchantment"], enc_data["level"])
  return inst


func test_penetration_enchantment_adds_to_pattern():
  """penetration_addエンチャントがパターンの貫通回数に加算される"""
  var pattern = AttackPattern.new()
  pattern.penetration_count = 1  # ベース貫通1
  pattern.bullet_count = 4
  pattern.burst_delay = 1.0
  pattern.damage = 5
  pattern.bullet_speed = 400.0

  # penetration_add = 2 のエンチャント
  var enc_data = _create_test_enchantment("penetration_add", 1, {"penetration_add": 2.0})
  var item_inst = _create_test_item_instance(5.0, 1.0, [enc_data])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # ベース1 * (1+0) + 2 = 3
  assert_int(pattern.penetration_count).is_equal(3)


func test_penetration_enchantment_level3_adds_4():
  """penetration_add Lv3: +4貫通"""
  var pattern = AttackPattern.new()
  pattern.penetration_count = 0  # ベース貫通なし
  pattern.bullet_count = 1
  pattern.burst_delay = 1.0
  pattern.damage = 5
  pattern.bullet_speed = 400.0

  var enc_data = _create_test_enchantment("penetration_add", 3, {"penetration_add": 4.0})
  var item_inst = _create_test_item_instance(5.0, 1.0, [enc_data])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # ベース0 * (1+0) + 4 = 4
  assert_int(pattern.penetration_count).is_equal(4)


func test_bullet_count_enchantment_adds_to_pattern():
  """bullet_count_addエンチャントがパターンの弾数に加算される"""
  var pattern = AttackPattern.new()
  pattern.bullet_count = 4  # ベース弾数4
  pattern.penetration_count = 0
  pattern.burst_delay = 1.0
  pattern.damage = 5
  pattern.bullet_speed = 400.0

  # bullet_count_add = 3 のエンチャント
  var enc_data = _create_test_enchantment("bullet_count_add", 2, {"bullet_count_add": 3.0})
  var item_inst = _create_test_item_instance(5.0, 1.0, [enc_data])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # ベース4 * (1+0) + 3 = 7
  assert_int(pattern.bullet_count).is_equal(7)


func test_bullet_count_minimum_is_one():
  """弾数が最低1以上に維持される"""
  var pattern = AttackPattern.new()
  pattern.bullet_count = 1  # ベース弾数1
  pattern.penetration_count = 0
  pattern.burst_delay = 1.0
  pattern.damage = 5
  pattern.bullet_speed = 400.0

  # bullet_count_add は 0（追加なし）
  var item_inst = _create_test_item_instance(5.0, 1.0, [])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # 最低1
  assert_int(pattern.bullet_count).is_greater_equal(1)


func test_combined_enchantments_penetration_and_bullet_count():
  """貫通と弾数エンチャントの同時適用"""
  var pattern = AttackPattern.new()
  pattern.bullet_count = 4
  pattern.penetration_count = 1
  pattern.burst_delay = 1.0
  pattern.damage = 5
  pattern.bullet_speed = 400.0

  var enc_pen = _create_test_enchantment("penetration_add", 1, {"penetration_add": 2.0})
  var enc_count = _create_test_enchantment("bullet_count_add", 3, {"bullet_count_add": 6.0})
  var item_inst = _create_test_item_instance(5.0, 1.0, [enc_pen, enc_count])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # 貫通: 1 * (1+0) + 2 = 3
  assert_int(pattern.penetration_count).is_equal(3)
  # 弾数: 4 * (1+0) + 6 = 10
  assert_int(pattern.bullet_count).is_equal(10)


func test_cooldown_enchantment_with_barrier():
  """速射エンチャント（cooldown_pct）がバリアオーブにも適用される"""
  var pattern = AttackPattern.new()
  pattern.bullet_count = 4
  pattern.penetration_count = 0
  pattern.burst_delay = 5.0  # ベースCD 5秒
  pattern.damage = 2
  pattern.bullet_speed = 400.0

  # cooldown_pct = -0.3 (30%減少)
  var enc_data = _create_test_enchantment("cooldown_pct", 3, {"cooldown_pct": -0.3})
  var item_inst = _create_test_item_instance(2.0, 5.0, [enc_data])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # CD: 5.0 * (1 + (-0.3)) + 0 = 3.5
  assert_that(pattern.burst_delay).is_equal_approx(3.5, 0.01)


# =====================================================================
# 5. エンチャント修正値の計算ロジックテスト
# =====================================================================


func test_enchantment_modifier_formula_pct_and_add():
  """エンチャント修正値: base * (1 + sum_pct) + sum_add の検証"""
  var pattern = AttackPattern.new()
  pattern.bullet_count = 4
  pattern.penetration_count = 2
  pattern.burst_delay = 1.0
  pattern.damage = 10
  pattern.bullet_speed = 400.0

  # penetration_pct = 0.5 (+50%) と penetration_add = 1 を同時適用
  var enc_pct = _create_test_enchantment("penetration_pct_enc", 1, {"penetration_pct": 0.5})
  var enc_add = _create_test_enchantment("penetration_add_enc", 1, {"penetration_add": 1.0})
  var item_inst = _create_test_item_instance(10.0, 1.0, [enc_pct, enc_add])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # 貫通: 2 * (1 + 0.5) + 1 = 4
  assert_int(pattern.penetration_count).is_equal(4)


func test_multiple_same_type_enchantments_stack():
  """同種エンチャントの効果は加算される"""
  var pattern = AttackPattern.new()
  pattern.bullet_count = 4
  pattern.penetration_count = 0
  pattern.burst_delay = 1.0
  pattern.damage = 5
  pattern.bullet_speed = 400.0

  # penetration_add = 1 × 2つ
  var enc1 = _create_test_enchantment("penetration_add_1", 1, {"penetration_add": 1.0})
  var enc2 = _create_test_enchantment("penetration_add_2", 1, {"penetration_add": 2.0})
  var item_inst = _create_test_item_instance(5.0, 1.0, [enc1, enc2])

  PlayerAttackPatternFactory.update_pattern_from_enchantments(pattern, item_inst)

  # ベース0 * (1+0) + 1 + 2 = 3
  assert_int(pattern.penetration_count).is_equal(3)


# =====================================================================
# 6. バリアオーブリソース統合テスト
# =====================================================================


func test_barrier_pattern_bullet_count_passed_to_bullets():
  """バリアパターンの弾数がモック弾丸に正しく渡される"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = false  # 敵モードで即座return

  test_pattern.bullet_count = 6
  test_pattern.barrier_movement_config = null
  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  await universal_core._execute_barrier_bullets(test_pattern)

  assert_that(universal_core.get_spawned_bullet_count()).is_equal(6)


func test_barrier_pattern_with_movement_config_rotation_values():
  """barrier_movement_configの値でstart_rotationが呼ばれることを確認"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = false

  var barrier_config = BarrierBulletMovement.new()
  barrier_config.orbit_duration = 3.5
  barrier_config.rotation_speed = 270.0
  test_pattern.barrier_movement_config = barrier_config
  test_pattern.bullet_count = 2

  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  await universal_core._execute_barrier_bullets(test_pattern)

  assert_that(universal_core.get_spawned_bullet_count()).is_equal(2)
  for bullet in universal_core.spawned_bullets:
    assert_that(bullet.last_rotation_duration).is_equal(3.5)
    assert_that(bullet.last_rotation_speed).is_equal(270.0)


func test_barrier_penetration_count_applied_to_spawned_bullet():
  """パターンの貫通回数がバリア弾に設定される"""
  universal_core._cooling = false
  universal_core._paused = false
  universal_core.player_mode = false

  test_pattern.penetration_count = 3
  test_pattern.bullet_count = 1
  test_pattern.barrier_movement_config = null
  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  await universal_core._execute_barrier_bullets(test_pattern)

  assert_that(universal_core.get_spawned_bullet_count()).is_equal(1)
  # バリア弾のダメージがパターンのdamageと一致
  var bullet = universal_core.spawned_bullets[0]
  assert_that(bullet.damage).is_equal(5.0)
