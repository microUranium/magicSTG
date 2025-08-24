# === UniversalAttackCore のテスト ===
extends GdUnitTestSuite
class_name UniversalAttackCoreTest

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

  # テスト専用クラスを使用（PackedSceneの問題を回避）
  universal_core = TestableUniversalAttackCore.new()
  test_scene.add_child(universal_core)
  universal_core.set_owner_actor(owner_actor)

  # シンプルなテストパターン
  test_pattern = AttackPattern.new()
  test_pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  test_pattern.bullet_count = 3
  test_pattern.damage = 10
  test_pattern.bullet_speed = 200.0

  # テスト用のダミー弾丸シーンを作成
  var dummy_bullet = BulletStub.new()
  var packed_bullet_scene := PackedScene.new()
  packed_bullet_scene.pack(dummy_bullet)
  test_pattern.bullet_scene = packed_bullet_scene


func after_test():
  test_scene.queue_free()


func test_single_shot_execution():
  """単発射撃の実行テスト（修正版）"""
  universal_core.attack_pattern = test_pattern

  var success = await universal_core._execute_single_shot(test_pattern)

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)


func test_rapid_fire_execution():
  """連射の実行テスト（修正版）"""
  test_pattern.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  test_pattern.rapid_fire_count = 3
  test_pattern.rapid_fire_interval = 0.1
  universal_core.attack_pattern = test_pattern

  universal_core.clear_spawned_bullets()

  var start_time = Time.get_time_dict_from_system()["second"]
  var success = await universal_core._execute_rapid_fire(test_pattern)
  var end_time = Time.get_time_dict_from_system()["second"]

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(9)  # 3発 × 3回

  var duration = end_time - start_time
  assert_that(duration).is_greater_equal(0.2)  # 最低限の時間


func test_firing_condition_validation():
  """発射条件の検証テスト（修正版）"""
  # パターンが設定されていない場合
  universal_core.attack_pattern = null
  var is_valid = universal_core._validate_firing_conditions()
  assert_that(is_valid).is_false()

  # オーナーが設定されていない場合
  universal_core.attack_pattern = test_pattern
  universal_core.set_owner_actor(null)
  is_valid = universal_core._validate_firing_conditions()
  assert_that(is_valid).is_false()

  # 正常な場合
  universal_core.set_owner_actor(owner_actor)
  is_valid = universal_core._validate_firing_conditions()
  assert_that(is_valid).is_true()


func test_spiral_pattern_execution():
  """螺旋パターンの実行テスト"""
  # コア状態をリセット
  universal_core._cooling = false
  universal_core._paused = false

  test_pattern.pattern_type = AttackPattern.PatternType.SPIRAL
  test_pattern.bullet_count = 8
  universal_core.attack_pattern = test_pattern

  universal_core.clear_spawned_bullets()

  var success = await universal_core._execute_spiral(test_pattern)

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(8)


func test_barrier_bullets_pattern():
  """バリア弾パターンのテスト"""
  # コア状態をリセット（前のテストの影響を除去）
  universal_core._cooling = false
  universal_core._paused = false

  test_pattern.pattern_type = AttackPattern.PatternType.BARRIER_BULLETS
  test_pattern.bullet_count = 6
  test_pattern.circle_radius = 80.0
  test_pattern.rotation_duration = 2.0
  universal_core.attack_pattern = test_pattern

  universal_core.clear_spawned_bullets()

  var success = await universal_core._execute_barrier_bullets(test_pattern)

  assert_that(success).is_true()
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(6)


func test_composite_pattern_execution():
  """複合パターンの実行テスト"""
  # コア状態をリセット
  universal_core._cooling = false
  universal_core._paused = false

  # レイヤー1: 単発射撃
  var layer1 = AttackPattern.new()
  layer1.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  layer1.bullet_count = 2
  layer1.damage = 5
  layer1.bullet_scene = test_pattern.bullet_scene

  # レイヤー2: 連射
  var layer2 = AttackPattern.new()
  layer2.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  layer2.bullet_count = 1
  layer2.rapid_fire_count = 2
  layer2.rapid_fire_interval = 0.05
  layer2.damage = 8
  layer2.bullet_scene = test_pattern.bullet_scene

  # 複合パターン作成
  var composite_pattern = AttackPattern.new()
  composite_pattern.pattern_layers.append(layer1)
  composite_pattern.pattern_layers.append(layer2)
  composite_pattern.layer_delays.append(0.0)
  composite_pattern.layer_delays.append(0.1)

  universal_core.attack_pattern = composite_pattern
  universal_core.clear_spawned_bullets()

  var success = await universal_core._execute_composite_pattern()

  assert_that(success).is_true()
  # レイヤー1: 2発 + レイヤー2: 2発 = 合計4発
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(4)


func test_direction_calculation():
  """方向計算のテスト"""
  # プレイヤー狙いの方向計算
  test_pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  var player_pos = Vector2(200, 200)
  var owner_pos = Vector2(100, 100)

  var direction = test_pattern.calculate_base_direction(owner_pos, player_pos)
  var expected = (player_pos - owner_pos).normalized()

  assert_that(direction.distance_to(expected)).is_less(0.01)

  # 固定方向の計算
  test_pattern.direction_type = AttackPattern.DirectionType.FIXED
  test_pattern.base_direction = Vector2.DOWN

  direction = test_pattern.calculate_base_direction(owner_pos, player_pos)
  assert_that(direction).is_equal(Vector2.DOWN)


func test_circle_direction_calculation():
  """円形配置の方向計算テスト"""
  var base_dir = Vector2.DOWN
  var bullet_count = 4

  # 各弾丸の方向を計算
  var directions = []
  for i in range(bullet_count):
    var dir = test_pattern.calculate_circle_direction(i, bullet_count, base_dir)
    directions.append(dir)

  # 4発の場合、90度ずつ配置されるはず
  assert_that(directions.size()).is_equal(4)

  # 各方向が単位ベクトルであることを確認
  for dir in directions:
    assert_that(abs(dir.length() - 1.0)).is_less(0.01)


func test_spread_direction_calculation():
  """扇状配置の方向計算テスト"""
  test_pattern.angle_spread = 90.0  # 90度の扇状
  var base_dir = Vector2.DOWN
  var bullet_count = 3

  var directions = []
  for i in range(bullet_count):
    var dir = test_pattern.calculate_spread_direction(i, bullet_count, base_dir)
    directions.append(dir)

  assert_that(directions.size()).is_equal(3)

  # 各方向が単位ベクトルであることを確認
  for dir in directions:
    assert_that(abs(dir.length() - 1.0)).is_less(0.01)


# === 警告線機能のテスト ===


func test_show_attack_warning_with_empty_configs():
  # Given - 警告設定が空の場合
  test_pattern.warning_configs = []
  universal_core.attack_pattern = test_pattern

  # When
  await universal_core._show_attack_warning()

  # Then - 何も起こらず即座に完了
  assert_that(true).is_true()  # 正常完了の確認


func test_show_attack_warning_with_single_config():
  # Given - 単一の警告設定
  var warning_config = AttackWarningConfig.new()
  warning_config.warning_duration = 0.1  # テスト用に短縮
  warning_config.warning_length = 100.0
  warning_config.angle_degrees = 0.0
  warning_config.position_offset = Vector2.ZERO
  warning_config.use_relative_position = true

  test_pattern.warning_configs = [warning_config]
  universal_core.attack_pattern = test_pattern

  # When
  await universal_core._show_attack_warning()

  # Then - 警告線が生成される（警告完了後に確認）
  var scene_children = get_tree().current_scene.get_children()
  var warning_found = false
  for child in scene_children:
    if child is AttackWarning:
      warning_found = true
      break

  assert_that(warning_found).is_true()


func test_show_attack_warning_with_multiple_configs():
  # Given - 複数の警告設定
  var config1 = AttackWarningConfig.new()
  config1.warning_duration = 0.1
  config1.angle_degrees = 0.0
  config1.position_offset = Vector2.ZERO
  config1.use_relative_position = true

  var config2 = AttackWarningConfig.new()
  config2.warning_duration = 0.1
  config2.angle_degrees = 90.0
  config2.position_offset = Vector2(10, 0)
  config2.use_relative_position = true

  var config3 = AttackWarningConfig.new()
  config3.warning_duration = 0.1
  config3.angle_degrees = -90.0
  config3.position_offset = Vector2(-10, 0)
  config3.use_relative_position = false  # 絶対座標

  test_pattern.warning_configs = [config1, config2, config3]
  universal_core.attack_pattern = test_pattern

  # When
  await universal_core._show_attack_warning()

  # Then - 3つの警告線が生成される（警告完了後に確認）
  var scene_children = get_tree().current_scene.get_children()
  var warning_count = 0
  for child in scene_children:
    if child is AttackWarning:
      warning_count += 1

  assert_that(warning_count).is_equal(3)


func test_warning_line_relative_vs_absolute_position():
  # Given - 相対座標と絶対座標の混在
  var relative_config = AttackWarningConfig.new()
  relative_config.warning_duration = 0.05
  relative_config.position_offset = Vector2(25, -15)
  relative_config.use_relative_position = true

  var absolute_config = AttackWarningConfig.new()
  absolute_config.warning_duration = 0.05
  absolute_config.position_offset = Vector2(200, 200)
  absolute_config.use_relative_position = false

  test_pattern.warning_configs = [relative_config, absolute_config]
  universal_core.attack_pattern = test_pattern

  # When
  await universal_core._show_attack_warning()

  # Then - 両方の警告線が生成される（警告完了後に確認）
  var scene_children = get_tree().current_scene.get_children()
  var relative_warnings = 0
  var absolute_warnings = 0

  for child in scene_children:
    if child is AttackWarning:
      if child.owner_node != null:
        relative_warnings += 1
      else:
        absolute_warnings += 1

  assert_that(relative_warnings).is_equal(1)
  assert_that(absolute_warnings).is_equal(1)


# === 後方射撃モードのテスト ===


func test_rear_firing_mode_toggle():
  """後方射撃モードのオン/オフテスト"""
  # Given - 通常モードで初期化
  test_pattern.direction_type = AttackPattern.DirectionType.FIXED
  universal_core.attack_pattern = test_pattern
  universal_core.clear_spawned_bullets()

  # When - 後方射撃モードをオンにして発射
  universal_core.set_rear_firing_mode(true)
  await universal_core._execute_single_shot(test_pattern)

  # Then - 弾丸の方向が後方を向いている
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)
  var rear_bullets = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードをオフにして再発射
  universal_core.clear_spawned_bullets()
  universal_core.set_rear_firing_mode(false)
  await universal_core._execute_single_shot(test_pattern)

  # Then - 弾丸の方向が通常を向いている
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)
  var normal_bullets = universal_core.spawned_bullets.duplicate()

  # 方向が反転していることを確認
  for i in range(min(rear_bullets.size(), normal_bullets.size())):
    var rear_dir = rear_bullets[i].direction
    var normal_dir = normal_bullets[i].direction
    var dot_product = rear_dir.dot(normal_dir)
    assert_that(dot_product).is_less(-0.9)  # ほぼ反対方向


func test_rear_firing_to_player_direction():
  """TO_PLAYER方向は後方射撃モードに関わらず同じ方向になることをテスト"""
  # Given - TO_PLAYERパターンを設定
  test_pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  universal_core.attack_pattern = test_pattern

  # プレイヤー位置をモック
  var mock_player = Node2D.new()
  mock_player.global_position = Vector2(200, 100)  # オーナーの右側
  test_scene.add_child(mock_player)

  # TargetServiceをモック（テスト用の簡易実装）
  TargetService.register_player(mock_player)

  # When - 通常モードで発射
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_single_shot(test_pattern)

  var normal_bullets = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードで発射
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_single_shot(test_pattern)

  var rear_bullets = universal_core.spawned_bullets

  # Then - TO_PLAYERの場合は後方射撃モードに関わらず同じ方向
  for i in range(min(rear_bullets.size(), normal_bullets.size())):
    var rear_dir = rear_bullets[i].direction
    var normal_dir = normal_bullets[i].direction
    var dot_product = rear_dir.dot(normal_dir)
    assert_that(dot_product).is_greater(0.9)  # ほぼ同じ方向

    # より厳密に：方向の差が小さいことを確認
    var direction_diff = rear_dir.distance_to(normal_dir)
    assert_that(direction_diff).is_less(0.1)  # 非常に近い方向

  # クリーンアップ
  mock_player.queue_free()


func test_rear_firing_rapid_fire():
  """後方射撃モード時の連射パターンテスト"""
  # Given - 連射パターンを設定
  test_pattern.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  test_pattern.rapid_fire_count = 2
  test_pattern.rapid_fire_interval = 0.05
  test_pattern.direction_type = AttackPattern.DirectionType.FIXED
  test_pattern.base_direction = Vector2.DOWN
  universal_core.attack_pattern = test_pattern

  # When - 通常モードで連射
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_rapid_fire(test_pattern)

  var normal_bullets = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードで連射
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_rapid_fire(test_pattern)

  var rear_bullets = universal_core.spawned_bullets

  # Then - 同じ数の弾丸が生成され、方向が反転している
  assert_that(rear_bullets.size()).is_equal(normal_bullets.size())

  for i in range(min(rear_bullets.size(), normal_bullets.size())):
    var rear_dir = rear_bullets[i].direction
    var normal_dir = normal_bullets[i].direction
    var dot_product = rear_dir.dot(normal_dir)
    assert_that(dot_product).is_less(-0.9)  # ほぼ反対方向


func test_rear_firing_spiral_pattern():
  """後方射撃モード時の螺旋パターンテスト"""
  # Given - 螺旋パターンを設定
  test_pattern.pattern_type = AttackPattern.PatternType.SPIRAL
  test_pattern.bullet_count = 4  # テスト用に少なめ
  test_pattern.direction_type = AttackPattern.DirectionType.FIXED
  test_pattern.base_direction = Vector2.RIGHT
  universal_core.attack_pattern = test_pattern

  # When - 通常モードで螺旋発射
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_spiral(test_pattern)

  var normal_bullets = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードで螺旋発射
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_spiral(test_pattern)

  var rear_bullets = universal_core.spawned_bullets

  # Then - 同じ数の弾丸が生成される
  assert_that(rear_bullets.size()).is_equal(normal_bullets.size())
  assert_that(rear_bullets.size()).is_equal(4)

  # 螺旋パターンでも基準方向が反転していることを確認
  # 螺旋の各弾丸の方向は複雑だが、全体的に反転していることをチェック
  var normal_center = Vector2.ZERO
  var rear_center = Vector2.ZERO

  for bullet in normal_bullets:
    normal_center += bullet.direction
  for bullet in rear_bullets:
    rear_center += bullet.direction

  normal_center = normal_center.normalized()
  rear_center = rear_center.normalized()

  var dot_product = normal_center.dot(rear_center)
  assert_that(dot_product).is_less(-0.5)  # 大まかに反対方向


func test_rear_firing_barrier_bullets():
  """後方射撃モード時のバリア弾パターンテスト"""
  # Given - バリア弾パターンを設定
  test_pattern.pattern_type = AttackPattern.PatternType.BARRIER_BULLETS
  test_pattern.bullet_count = 3  # テスト用に少なめ
  test_pattern.circle_radius = 50.0
  test_pattern.rotation_duration = 1.0
  universal_core.attack_pattern = test_pattern

  # When - 後方射撃モードでバリア弾発射
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_barrier_bullets(test_pattern)

  # Then - 弾丸が生成される（バリア弾は方向反転の影響を受けにくいが、生成自体は成功する）
  assert_that(universal_core.get_spawned_bullet_count()).is_equal(3)


func test_rear_firing_mode_persistence():
  """後方射撃モードの状態持続テスト"""
  # Given - 初期状態は通常モード
  universal_core.attack_pattern = test_pattern

  # When - 後方射撃モードを有効にし、複数回発射
  universal_core.set_rear_firing_mode(true)

  universal_core.clear_spawned_bullets()
  await universal_core._execute_single_shot(test_pattern)
  var first_shot_count = universal_core.get_spawned_bullet_count()

  await universal_core._execute_single_shot(test_pattern)
  var second_shot_count = universal_core.get_spawned_bullet_count()

  # Then - 後方射撃モードが持続している
  assert_that(first_shot_count).is_equal(3)
  assert_that(second_shot_count).is_equal(6)  # 前回の3発 + 今回の3発

  # すべての弾丸の方向をチェック
  var all_bullets = universal_core.spawned_bullets
  for bullet in all_bullets:
    # 後方射撃なので、方向がマイナス方向成分を持つはず
    # （具体的な方向は設定による）
    assert_that(bullet.direction).is_not_equal(Vector2.ZERO)


func test_rear_firing_beam_single():
  """後方射撃モード時の単発ビームテスト"""
  # Given - 単発ビームパターンを設定
  var beam_pattern = AttackPattern.new()
  beam_pattern.pattern_type = AttackPattern.PatternType.BEAM
  beam_pattern.bullet_count = 1
  beam_pattern.beam_duration = 1.0
  beam_pattern.damage = 15
  beam_pattern.direction_type = AttackPattern.DirectionType.FIXED
  beam_pattern.base_direction = Vector2.UP

  # ダミービームシーンを作成
  var dummy_beam = Node2D.new()
  var packed_beam_scene := PackedScene.new()
  packed_beam_scene.pack(dummy_beam)
  beam_pattern.beam_scene = packed_beam_scene

  universal_core.attack_pattern = beam_pattern

  # When - 通常モードでビーム発射
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_beam(beam_pattern)

  var normal_beams = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードでビーム発射
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_beam(beam_pattern)

  var rear_beams = universal_core.spawned_bullets

  # Then - 同じ数のビームが生成され、方向が反転している
  assert_that(rear_beams.size()).is_equal(normal_beams.size())
  assert_that(rear_beams.size()).is_equal(1)

  var normal_dir = normal_beams[0].direction
  var rear_dir = rear_beams[0].direction
  var dot_product = normal_dir.dot(rear_dir)
  assert_that(dot_product).is_less(-0.9)  # ほぼ反対方向


func test_rear_firing_beam_multiple():
  """後方射撃モード時の複数ビームテスト"""
  # Given - 複数ビームパターンを設定
  var beam_pattern = AttackPattern.new()
  beam_pattern.pattern_type = AttackPattern.PatternType.BEAM
  beam_pattern.bullet_count = 3  # 3本のビーム
  beam_pattern.beam_duration = 1.0
  beam_pattern.damage = 12
  beam_pattern.direction_type = AttackPattern.DirectionType.FIXED
  beam_pattern.base_direction = Vector2.DOWN
  beam_pattern.angle_spread = 60.0  # 60度の扇状

  # ダミービームシーンを作成
  var dummy_beam = Node2D.new()
  var packed_beam_scene := PackedScene.new()
  packed_beam_scene.pack(dummy_beam)
  beam_pattern.beam_scene = packed_beam_scene

  universal_core.attack_pattern = beam_pattern

  # When - 通常モードで複数ビーム発射
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_beam(beam_pattern)

  var normal_beams = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードで複数ビーム発射
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_beam(beam_pattern)

  var rear_beams = universal_core.spawned_bullets

  # Then - 同じ数のビームが生成される
  assert_that(rear_beams.size()).is_equal(normal_beams.size())
  assert_that(rear_beams.size()).is_equal(3)

  # 各ビームの方向が反転していることを確認
  for i in range(min(rear_beams.size(), normal_beams.size())):
    var rear_dir = rear_beams[i].direction
    var normal_dir = normal_beams[i].direction
    var dot_product = rear_dir.dot(normal_dir)
    assert_that(dot_product).is_less(-0.8)  # ほぼ反対方向


func test_rear_firing_beam_to_player():
  """TO_PLAYERビームは後方射撃モードに関わらず同じ方向になることをテスト"""
  # Given - TO_PLAYERビームパターンを設定
  var beam_pattern = AttackPattern.new()
  beam_pattern.pattern_type = AttackPattern.PatternType.BEAM
  beam_pattern.bullet_count = 1
  beam_pattern.beam_duration = 0.5
  beam_pattern.damage = 20
  beam_pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER

  # ダミービームシーンを作成
  var dummy_beam = Node2D.new()
  var packed_beam_scene := PackedScene.new()
  packed_beam_scene.pack(dummy_beam)
  beam_pattern.beam_scene = packed_beam_scene

  # プレイヤー位置をモック
  var mock_player = Node2D.new()
  mock_player.global_position = Vector2(300, 100)  # オーナーの右側
  test_scene.add_child(mock_player)
  TargetService.register_player(mock_player)

  universal_core.attack_pattern = beam_pattern

  # When - 通常モードでビーム発射
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_beam(beam_pattern)

  var normal_beams = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードでビーム発射
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_beam(beam_pattern)

  var rear_beams = universal_core.spawned_bullets

  # Then - TO_PLAYERの場合は後方射撃モードに関わらず同じ方向
  assert_that(rear_beams.size()).is_equal(1)
  assert_that(normal_beams.size()).is_equal(1)

  var normal_dir = normal_beams[0].direction
  var rear_dir = rear_beams[0].direction
  var dot_product = normal_dir.dot(rear_dir)
  assert_that(dot_product).is_greater(0.9)  # ほぼ同じ方向

  # より厳密に：方向の差が小さいことを確認
  var direction_diff = normal_dir.distance_to(rear_dir)
  assert_that(direction_diff).is_less(0.1)  # 非常に近い方向

  # クリーンアップ
  mock_player.queue_free()


func test_rear_firing_composite_pattern():
  """後方射撃モード時の複合パターンテスト"""
  # Given - 複合パターンを設定
  # レイヤー1: 単発射撃（固定方向）
  var layer1 = AttackPattern.new()
  layer1.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  layer1.bullet_count = 2
  layer1.damage = 5
  layer1.direction_type = AttackPattern.DirectionType.FIXED
  layer1.base_direction = Vector2.RIGHT
  layer1.bullet_scene = test_pattern.bullet_scene

  # レイヤー2: 連射（プレイヤー狙い）
  var layer2 = AttackPattern.new()
  layer2.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  layer2.bullet_count = 1
  layer2.rapid_fire_count = 2
  layer2.rapid_fire_interval = 0.02
  layer2.damage = 8
  layer2.direction_type = AttackPattern.DirectionType.TO_PLAYER
  layer2.bullet_scene = test_pattern.bullet_scene

  # 複合パターン作成
  var composite_pattern = AttackPattern.new()
  composite_pattern.pattern_layers.append(layer1)
  composite_pattern.pattern_layers.append(layer2)
  composite_pattern.layer_delays.append(0.0)
  composite_pattern.layer_delays.append(0.05)

  # プレイヤー位置をモック
  var mock_player = Node2D.new()
  mock_player.global_position = Vector2(150, 50)
  test_scene.add_child(mock_player)
  TargetService.register_player(mock_player)

  universal_core.attack_pattern = composite_pattern

  # When - 通常モードで複合パターン実行
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_composite_pattern()

  var normal_bullets = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードで複合パターン実行
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_composite_pattern()

  var rear_bullets = universal_core.spawned_bullets

  # Then - 同じ数の弾丸が生成される
  assert_that(rear_bullets.size()).is_equal(normal_bullets.size())
  assert_that(rear_bullets.size()).is_equal(4)  # レイヤー1: 2発 + レイヤー2: 2発

  # レイヤー1（FIXED）の弾丸は方向が反転、レイヤー2（TO_PLAYER）の弾丸は同じ方向
  for i in range(min(rear_bullets.size(), normal_bullets.size())):
    var rear_dir = rear_bullets[i].direction
    var normal_dir = normal_bullets[i].direction
    var dot_product = rear_dir.dot(normal_dir)

    if i < 2:  # レイヤー1のFIXED方向弾丸
      assert_that(dot_product).is_less(-0.7)  # ほぼ反対方向
    else:  # レイヤー2のTO_PLAYER弾丸
      assert_that(dot_product).is_greater(0.7)  # ほぼ同じ方向

  # クリーンアップ
  mock_player.queue_free()


func test_rear_firing_with_mixed_patterns():
  """後方射撃モード時の混合パターン（ビーム+弾丸）テスト"""
  # Given - ビームと弾丸の混合複合パターン
  # レイヤー1: ビーム
  var beam_layer = AttackPattern.new()
  beam_layer.pattern_type = AttackPattern.PatternType.BEAM
  beam_layer.bullet_count = 1
  beam_layer.beam_duration = 0.1
  beam_layer.damage = 10
  beam_layer.direction_type = AttackPattern.DirectionType.FIXED
  beam_layer.base_direction = Vector2.UP

  var dummy_beam = Node2D.new()
  var packed_beam_scene := PackedScene.new()
  packed_beam_scene.pack(dummy_beam)
  beam_layer.beam_scene = packed_beam_scene

  # レイヤー2: 単発射撃
  var bullet_layer = AttackPattern.new()
  bullet_layer.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  bullet_layer.bullet_count = 2
  bullet_layer.damage = 7
  bullet_layer.direction_type = AttackPattern.DirectionType.FIXED
  bullet_layer.base_direction = Vector2.DOWN
  bullet_layer.bullet_scene = test_pattern.bullet_scene

  # 複合パターン作成
  var mixed_pattern = AttackPattern.new()
  mixed_pattern.pattern_layers.append(beam_layer)
  mixed_pattern.pattern_layers.append(bullet_layer)
  mixed_pattern.layer_delays.append(0.0)
  mixed_pattern.layer_delays.append(0.05)

  universal_core.attack_pattern = mixed_pattern

  # When - 通常モードで混合パターン実行
  universal_core.set_rear_firing_mode(false)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_composite_pattern()

  var normal_projectiles = universal_core.spawned_bullets.duplicate()

  # When - 後方射撃モードで混合パターン実行
  universal_core.set_rear_firing_mode(true)
  universal_core.clear_spawned_bullets()
  await universal_core._execute_composite_pattern()

  var rear_projectiles = universal_core.spawned_bullets

  # Then - ビームと弾丸の両方が正常に生成され、方向が反転している
  assert_that(rear_projectiles.size()).is_equal(normal_projectiles.size())
  assert_that(rear_projectiles.size()).is_equal(3)  # ビーム1発 + 弾丸2発

  # 各プロジェクタイルの方向が反転していることを確認
  for i in range(min(rear_projectiles.size(), normal_projectiles.size())):
    var rear_dir = rear_projectiles[i].direction
    var normal_dir = normal_projectiles[i].direction
    var dot_product = rear_dir.dot(normal_dir)
    assert_that(dot_product).is_less(-0.8)  # ほぼ反対方向
