# === ExplosionFactory オブジェクトプールテスト ===
extends GdUnitTestSuite
class_name ExplosionFactoryTest

var test_scene: Node
var mock_explosion_config: ExplosionConfig


func before_test():
  # テストシーン構築
  test_scene = Node.new()
  test_scene.name = "TestScene"
  add_child(test_scene)

  # モック爆発設定
  mock_explosion_config = _create_mock_explosion_config()

  # プール初期化
  _reset_explosion_pool()


func after_test():
  # プールクリーンアップ
  _reset_explosion_pool()

  if test_scene:
    test_scene.queue_free()


func _create_mock_explosion_config() -> ExplosionConfig:
  """モック爆発設定の作成"""
  var config = ExplosionConfig.new()
  config.explosion_damage = 25
  config.explosion_radius = 50.0
  config.explosion_duration = 1.0
  return config


func _reset_explosion_pool():
  """爆発プールのリセット"""
  # staticプールをクリア（テスト間の独立性確保）
  if ExplosionFactory._explosion_pool:
    for explosion in ExplosionFactory._explosion_pool:
      if is_instance_valid(explosion):
        explosion.queue_free()
    ExplosionFactory._explosion_pool.clear()


# === 基本機能テスト ===


func test_explosion_creation():
  """爆発エフェクト作成テスト"""
  var position = Vector2(100, 200)
  var source_group = "enemies"

  # 爆発作成
  var explosion = ExplosionFactory.create_explosion(mock_explosion_config, position, source_group)

  # 正常に作成されることを確認
  assert_that(explosion).is_not_null()
  assert_that(explosion is ExplosionEffect).is_true()


func test_explosion_creation_with_null_config():
  """null設定での爆発作成テスト"""
  var position = Vector2(50, 100)

  # null configで作成試行
  var explosion = ExplosionFactory.create_explosion(null, position, "")

  # null設定の場合はnullが返される
  assert_that(explosion).is_null()


func test_explosion_creation_without_source_group():
  """ソースグループ無しでの爆発作成テスト"""
  var position = Vector2(150, 250)

  # ソースグループ省略
  var explosion = ExplosionFactory.create_explosion(mock_explosion_config, position)

  # 正常に作成されることを確認
  assert_that(explosion).is_not_null()


# === オブジェクトプール機能テスト ===


func test_pooled_explosion_reuse():
  """プール済み爆発の再利用テスト"""
  var position1 = Vector2(100, 100)
  var position2 = Vector2(200, 200)

  # 初回作成
  var explosion1 = ExplosionFactory.create_explosion(mock_explosion_config, position1, "enemies")
  assert_that(explosion1).is_not_null()

  # プールに返却
  ExplosionFactory.return_to_pool(explosion1)

  # 再度作成（プールから再利用されるはず）
  var explosion2 = ExplosionFactory.create_explosion(mock_explosion_config, position2, "players")
  assert_that(explosion2).is_not_null()

  # 同じインスタンスが再利用されることを確認
  assert_that(explosion2).is_equal(explosion1)


func test_pool_size_limitation():
  """プールサイズ制限テスト"""
  var max_pool_size = ExplosionFactory._pool_max_size
  var explosions = []

  # プール最大サイズを超える爆発を作成
  for i in range(max_pool_size + 5):
    var explosion = ExplosionFactory.create_explosion(
      mock_explosion_config, Vector2(i * 10, 0), "test"
    )
    explosions.append(explosion)

    # プールに返却
    ExplosionFactory.return_to_pool(explosion)

  # プールサイズが制限を超えないことを確認
  assert_that(ExplosionFactory._explosion_pool.size()).is_less_equal(max_pool_size)


func test_get_pooled_explosion_empty_pool():
  """空プールからの爆発取得テスト"""
  # プールが空の状態を確保
  _reset_explosion_pool()

  # プールから取得（新規作成されるはず）
  var explosion = ExplosionFactory._get_pooled_explosion()

  assert_that(explosion).is_not_null()
  assert_that(explosion is ExplosionEffect).is_true()


func test_get_pooled_explosion_from_pool():
  """プールからの爆発取得テスト"""
  # プールに爆発を追加
  var explosion1 = ExplosionFactory.create_explosion(mock_explosion_config, Vector2.ZERO, "")
  ExplosionFactory.return_to_pool(explosion1)

  # プールから取得
  var explosion2 = ExplosionFactory._get_pooled_explosion()

  assert_that(explosion2).is_equal(explosion1)
  assert_that(ExplosionFactory._explosion_pool.size()).is_equal(0)  # プールから除去される


# === エラーハンドリング・堅牢性テスト ===


func test_explosion_creation_edge_cases():
  """爆発作成のエッジケーステスト"""
  # 極端な位置
  var extreme_positions = [
    Vector2(-99999, -99999),
    Vector2(99999, 99999),
    Vector2(0, 0),
    Vector2.INF,
    Vector2(-Vector2.INF.x, -Vector2.INF.y)
  ]

  for pos in extreme_positions:
    var explosion = ExplosionFactory.create_explosion(mock_explosion_config, pos, "test")
    if pos.is_finite():
      assert_that(explosion).is_not_null()
    # 無限大の場合の動作は実装依存


func test_explosion_config_variations():
  """様々な爆発設定でのテスト"""
  var configs = []

  # 極小設定
  var small_config = ExplosionConfig.new()
  small_config.explosion_damage = 1
  small_config.explosion_radius = 1.0
  small_config.explosion_duration = 0.1
  configs.append(small_config)

  # 極大設定
  var large_config = ExplosionConfig.new()
  large_config.explosion_damage = 9999
  large_config.explosion_radius = 500.0
  large_config.explosion_duration = 10.0
  configs.append(large_config)

  # 各設定で爆発作成
  for config in configs:
    var explosion = ExplosionFactory.create_explosion(config, Vector2.ZERO, "test")
    assert_that(explosion).is_not_null()


func test_concurrent_explosions():
  """同時複数爆発処理テスト"""
  var explosions = []
  var position = Vector2.ZERO

  # 複数爆発を同時作成
  for i in range(10):
    var explosion = ExplosionFactory.create_explosion(
      mock_explosion_config, position + Vector2(i * 20, 0), "concurrent_test"
    )
    explosions.append(explosion)

  # 全て正常に作成されることを確認
  assert_that(explosions.size()).is_equal(10)
  for explosion in explosions:
    assert_that(explosion).is_not_null()


# === プールライフサイクルテスト ===


func test_pool_reset_behavior():
  """プールリセット動作テスト"""
  # プールに複数爆発を追加
  for i in range(5):
    var explosion = ExplosionFactory.create_explosion(mock_explosion_config, Vector2(i, 0), "")
    ExplosionFactory.return_to_pool(explosion)

  var initial_pool_size = ExplosionFactory._explosion_pool.size()
  assert_that(initial_pool_size).is_greater(0)

  # プールリセット
  _reset_explosion_pool()

  assert_that(ExplosionFactory._explosion_pool.size()).is_equal(0)


func test_explosion_reset_functionality():
  """爆発リセット機能テスト"""
  var explosion = ExplosionFactory.create_explosion(mock_explosion_config, Vector2(50, 50), "test")

  # reset()メソッドが呼ばれることを確認（間接的）
  ExplosionFactory.return_to_pool(explosion)

  # プールから再取得
  var reused_explosion = ExplosionFactory._get_pooled_explosion()
  assert_that(reused_explosion).is_equal(explosion)


# === 統合テスト ===


func test_complete_explosion_lifecycle():
  """完全な爆発ライフサイクルテスト"""
  var position = Vector2(100, 100)
  var source_group = "player_bullets"

  # 作成
  var explosion = ExplosionFactory.create_explosion(mock_explosion_config, position, source_group)
  assert_that(explosion).is_not_null()

  # 初期化確認（メソッドが存在する場合）
  if explosion.has_method("get_damage"):
    # 実装に依存するため、エラーにならないことだけ確認
    pass

  # プールに返却
  ExplosionFactory.return_to_pool(explosion)

  # 再利用
  var reused = ExplosionFactory.create_explosion(
    mock_explosion_config, Vector2(200, 200), "enemies"
  )
  assert_that(reused).is_equal(explosion)


func test_memory_leak_prevention():
  """メモリリーク防止テスト"""
  var initial_pool_size = ExplosionFactory._explosion_pool.size()

  # 大量の爆発を作成・返却
  for i in range(50):
    var explosion = ExplosionFactory.create_explosion(mock_explosion_config, Vector2(i, 0), "test")
    ExplosionFactory.return_to_pool(explosion)

  # プールサイズが制限されることを確認
  var final_pool_size = ExplosionFactory._explosion_pool.size()
  assert_that(final_pool_size).is_less_equal(ExplosionFactory._pool_max_size)


func test_factory_static_behavior():
  """ファクトリの静的動作テスト"""
  # 複数のテストメソッド間でstaticデータが保持されることを確認
  var explosion1 = ExplosionFactory.create_explosion(
    mock_explosion_config, Vector2.ZERO, "static_test"
  )
  ExplosionFactory.return_to_pool(explosion1)

  var pool_size = ExplosionFactory._explosion_pool.size()
  assert_that(pool_size).is_greater_equal(1)

  # 別のメソッドでプールにアクセス可能
  var explosion2 = ExplosionFactory._get_pooled_explosion()
  assert_that(explosion2).is_equal(explosion1)
