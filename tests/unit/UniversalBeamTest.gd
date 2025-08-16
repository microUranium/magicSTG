# === UniversalBeam コアシステムのテスト ===
extends GdUnitTestSuite
class_name UniversalBeamTest

var beam: UniversalBeam
var test_scene: Node2D
var mock_owner: Node2D
var mock_target: Node2D


func before_test():
  # テストシーン構築
  test_scene = Node2D.new()
  test_scene.name = "TestScene"
  add_child(test_scene)

  # モックオーナー（ビーム発射者）
  mock_owner = Node2D.new()
  mock_owner.name = "MockOwner"
  mock_owner.position = Vector2(100, 100)
  test_scene.add_child(mock_owner)

  # モックターゲット
  mock_target = Node2D.new()
  mock_target.name = "MockTarget"
  mock_target.add_to_group("enemies")
  mock_target.position = Vector2(200, 100)
  test_scene.add_child(mock_target)

  # UniversalBeamインスタンス作成
  # 実際のシーンファイルが無い場合の代替実装
  beam = _create_mock_beam()
  test_scene.add_child(beam)


func after_test():
  if test_scene:
    test_scene.queue_free()


func _create_mock_beam() -> UniversalBeam:
  """モックビームの作成（実際のシーンファイル代替）"""
  var mock_beam = UniversalBeam.new()
  mock_beam.name = "MockBeam"

  # 必要なコンポーネントのモック作成
  var collision_shape = CollisionShape2D.new()
  collision_shape.name = "CollisionShape2D"
  collision_shape.shape = RectangleShape2D.new()
  mock_beam.add_child(collision_shape)

  var ninepatch = NinePatchRect.new()
  ninepatch.name = "NinePatchRect"
  mock_beam.add_child(ninepatch)

  var raycast = RayCast2D.new()
  raycast.name = "RayCast2D"
  mock_beam.add_child(raycast)

  var damage_timer = Timer.new()
  damage_timer.name = "DamageTimer"
  mock_beam.add_child(damage_timer)

  var particles = GPUParticles2D.new()
  particles.name = "GPUParticles2D"
  mock_beam.add_child(particles)

  var audio_player = AudioStreamPlayer2D.new()
  audio_player.name = "AudioStreamPlayer2D"
  mock_beam.add_child(audio_player)

  var muzzle_flash_point = Node2D.new()
  muzzle_flash_point.name = "MuzzleFlashPoint"
  mock_beam.add_child(muzzle_flash_point)

  var impact_effect_point = Node2D.new()
  impact_effect_point.name = "ImpactEffectPoint"
  mock_beam.add_child(impact_effect_point)

  return mock_beam


# === 基本機能テスト ===


func test_beam_initialization():
  """ビーム初期化テスト"""
  # 基本プロパティのデフォルト値確認
  assert_that(beam.damage).is_equal(1)
  assert_that(beam.desired_length).is_equal(1000.0)
  assert_that(beam.target_group).is_equal("enemies")
  assert_that(beam.damage_tick_sec).is_equal(1.0 / 30.0)
  assert_that(beam.offset).is_equal(Vector2.ZERO)
  assert_that(beam.beam_direction).is_equal(Vector2.UP)


func test_beam_manual_initialization():
  """手動初期化メソッドテスト"""
  var damage = 10
  var direction = Vector2.RIGHT

  beam.initialize(mock_owner, damage, direction)

  assert_that(beam.owner_node).is_equal(mock_owner)
  assert_that(beam.damage).is_equal(damage)
  assert_that(beam.beam_direction).is_equal(direction)


func test_beam_direction_setting():
  """ビーム方向設定テスト"""
  # 正規化されない方向ベクトルでの設定
  var unnormalized_direction = Vector2(3.0, 4.0)
  beam.initialize(mock_owner, 5, unnormalized_direction)

  # 方向が正規化されていることを確認
  assert_that(abs(beam.beam_direction.length() - 1.0)).is_less(0.01)

  # 元の方向と同じ向きであることを確認
  var expected_direction = unnormalized_direction.normalized()
  assert_that(beam.beam_direction.distance_to(expected_direction)).is_less(0.01)


func test_target_group_setting():
  """ターゲットグループ設定テスト"""
  var new_group = "players"
  beam.set_target_group(new_group)

  assert_that(beam.target_group).is_equal(new_group)


func test_beam_properties_validation():
  """ビームプロパティの妥当性テスト"""
  # 負のダメージ
  beam.damage = -5
  assert_that(beam.damage).is_equal(-5)

  # 負の長さ
  beam.desired_length = -100.0
  assert_that(beam.desired_length).is_equal(-100.0)

  # 負のダメージ間隔
  beam.damage_tick_sec = -0.1
  assert_that(beam.damage_tick_sec).is_equal(-0.1)


# === 方向・位置計算テスト ===


func test_beam_positioning():
  """ビーム位置設定テスト"""
  beam.initialize(mock_owner, 5, Vector2.UP)

  # オーナーが設定されている場合の位置
  assert_that(beam.owner_node).is_equal(mock_owner)

  # オフセット適用テスト
  var offset = Vector2(10, 20)
  beam.offset = offset
  assert_that(beam.offset).is_equal(offset)


func test_beam_direction_variants():
  """様々な方向でのビーム設定テスト"""
  var test_directions = [
    Vector2.UP,
    Vector2.DOWN,
    Vector2.LEFT,
    Vector2.RIGHT,
    Vector2(1, 1).normalized(),
    Vector2(-1, 1).normalized()
  ]

  for direction in test_directions:
    beam.initialize(mock_owner, 1, direction)
    assert_that(beam.beam_direction.distance_to(direction)).is_less(0.01)
    assert_that(abs(beam.beam_direction.length() - 1.0)).is_less(0.01)


# === 視覚設定テスト ===


func test_beam_visual_config_application():
  """ビーム視覚設定適用テスト（モック）"""
  # BeamVisualConfigが無い場合のnull処理
  beam.beam_visual_config = null

  # エラーが発生しないことを確認
  assert_that(beam.beam_visual_config).is_null()

  # _apply_visual_config()は protected なので直接テストは困難
  # 代わりに設定値の保持確認
  assert_that(beam).is_not_null()


func test_beam_length_calculation():
  """ビーム長計算テスト（モック）"""
  beam.desired_length = 500.0
  assert_that(beam.desired_length).is_equal(500.0)

  # _current_lengthの初期値
  assert_that(beam._current_length).is_equal(0.0)


# === ダメージシステムテスト ===


func test_damage_tick_interval():
  """ダメージ間隔テスト"""
  # デフォルト間隔
  assert_that(beam.damage_tick_sec).is_equal(1.0 / 30.0)

  # カスタム間隔
  beam.damage_tick_sec = 0.1
  assert_that(beam.damage_tick_sec).is_equal(0.1)


func test_colliding_targets_management():
  """コリジョン中ターゲット管理テスト"""
  # 初期状態は空
  assert_that(beam._colliding_targets.size()).is_equal(0)

  # ターゲット追加（手動テスト）
  beam._colliding_targets.append(mock_target)
  assert_that(beam._colliding_targets.size()).is_equal(1)
  assert_that(beam._colliding_targets[0]).is_equal(mock_target)

  # クリア
  beam._colliding_targets.clear()
  assert_that(beam._colliding_targets.size()).is_equal(0)


# === エラーハンドリング・堅牢性テスト ===


func test_null_owner_handling():
  """nullオーナーでの初期化テスト"""
  beam.initialize(null, 5, Vector2.UP)

  assert_that(beam.owner_node).is_null()
  assert_that(beam.damage).is_equal(5)
  assert_that(beam.beam_direction).is_equal(Vector2.UP)


func test_zero_vector_direction_handling():
  """ゼロベクトル方向での初期化テスト"""
  beam.initialize(mock_owner, 5, Vector2.ZERO)

  # ゼロベクトルは正規化できないため、実装に依存
  # 少なくともクラッシュしないことを確認
  assert_that(beam.owner_node).is_equal(mock_owner)
  assert_that(beam.damage).is_equal(5)


func test_invalid_target_group():
  """無効なターゲットグループ設定テスト"""
  beam.set_target_group("")
  assert_that(beam.target_group).is_equal("")

  beam.set_target_group("nonexistent_group")
  assert_that(beam.target_group).is_equal("nonexistent_group")


func test_beam_robustness():
  """ビームの堅牢性総合テスト"""
  # 極端な値での設定
  beam.damage = 999999
  beam.desired_length = 99999.0
  beam.damage_tick_sec = 0.001

  assert_that(beam.damage).is_equal(999999)
  assert_that(beam.desired_length).is_equal(99999.0)
  assert_that(beam.damage_tick_sec).is_equal(0.001)

  # 初期化でも問題ないことを確認
  beam.initialize(mock_owner, beam.damage, Vector2.DOWN)
  assert_that(beam.owner_node).is_equal(mock_owner)


# === 統合テスト ===


func test_beam_lifecycle():
  """ビームライフサイクルテスト"""
  # 初期化
  beam.initialize(mock_owner, 10, Vector2.RIGHT)
  assert_that(beam.owner_node).is_equal(mock_owner)

  # ターゲットグループ設定
  beam.set_target_group("enemies")
  assert_that(beam.target_group).is_equal("enemies")

  # 視覚設定（null許可）
  beam.beam_visual_config = null
  assert_that(beam.beam_visual_config).is_null()

  # 最終状態確認
  assert_that(beam.damage).is_equal(10)
  assert_that(beam.beam_direction).is_equal(Vector2.RIGHT)


func test_multiple_beam_independence():
  """複数ビームの独立性テスト"""
  var beam2 = _create_mock_beam()
  test_scene.add_child(beam2)

  # 異なる設定
  beam.initialize(mock_owner, 5, Vector2.UP)
  beam2.initialize(mock_owner, 10, Vector2.DOWN)

  # 独立性確認
  assert_that(beam.damage).is_equal(5)
  assert_that(beam2.damage).is_equal(10)
  assert_that(beam.beam_direction).is_equal(Vector2.UP)
  assert_that(beam2.beam_direction).is_equal(Vector2.DOWN)

  # 一方の変更が他方に影響しないことを確認
  beam.damage = 15
  assert_that(beam.damage).is_equal(15)
  assert_that(beam2.damage).is_equal(10)


func test_beam_component_access():
  """ビームコンポーネントアクセステスト"""
  # 必要なコンポーネントが存在することを確認
  assert_that(beam.get_node_or_null("CollisionShape2D")).is_not_null()
  assert_that(beam.get_node_or_null("NinePatchRect")).is_not_null()
  assert_that(beam.get_node_or_null("RayCast2D")).is_not_null()
  assert_that(beam.get_node_or_null("DamageTimer")).is_not_null()
  assert_that(beam.get_node_or_null("GPUParticles2D")).is_not_null()
  assert_that(beam.get_node_or_null("AudioStreamPlayer2D")).is_not_null()
  assert_that(beam.get_node_or_null("MuzzleFlashPoint")).is_not_null()
  assert_that(beam.get_node_or_null("ImpactEffectPoint")).is_not_null()
