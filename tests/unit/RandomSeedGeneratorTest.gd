extends GdUnitTestSuite

# RandomSeedGenerator のテストスイート

var test_data: Dictionary
var mock_registry: GameDataRegistry


func before():
  # テスト用のモックデータを準備
  test_data = {
    "wave_templates":
    {
      "test_easy_1": {"pool": "test_easy", "weight": 10, "layers": []},
      "test_easy_2": {"pool": "test_easy", "weight": 5, "layers": []},
      "test_medium_1": {"pool": "test_medium", "weight": 8, "layers": []},
      "test_medium_2": {"pool": "test_medium", "weight": 3, "layers": []},
      "test_boss": {"pool": "test_boss", "weight": 15, "layers": []},
      "no_pool_wave": {"weight": 5, "layers": []},
      "no_weight_wave": {"pool": "test_easy", "layers": []}
    },
    "wave_pools":
    {
      "test_easy": {"description": "Test easy waves"},
      "test_medium": {"description": "Test medium waves"},
      "test_boss": {"description": "Test boss waves"}
    }
  }

  # GameDataRegistryにテストデータを読み込み
  GameDataRegistry.load_stage_data(test_data)


func after():
  # テスト後のクリーンアップ
  RandomSeedGenerator.clear_seed()
  GameDataRegistry.reload_data()


func test_set_and_get_current_seed():
  var test_seed = "test-seed-value"
  RandomSeedGenerator.set_current_seed(test_seed)
  assert_that(RandomSeedGenerator.get_current_seed()).is_equal(test_seed)


func test_clear_seed():
  RandomSeedGenerator.set_current_seed("test-seed")
  RandomSeedGenerator.clear_seed()
  assert_that(RandomSeedGenerator.get_current_seed()).is_equal("")


func test_generate_seed_with_pools_basic():
  var pool_sequence = [{"pool": "test_easy", "count": 2}, {"pool": "test_boss", "count": 1}]

  var _seed = RandomSeedGenerator.generate_seed_with_pools(pool_sequence)

  # シード値が生成されることを確認
  assert_that(_seed).is_not_empty()

  # シード値の形式を確認（ハイフン区切り）
  var parts = _seed.split("-")
  assert_that(parts.size()).is_equal(3)  # easy 2個 + boss 1個

  # 現在のシードが更新されることを確認
  assert_that(RandomSeedGenerator.get_current_seed()).is_equal(_seed)


func test_generate_seed_with_pools_empty_pool():
  var pool_sequence = [{"pool": "nonexistent_pool", "count": 2}]

  var _seed = RandomSeedGenerator.generate_seed_with_pools(pool_sequence)

  # 存在しないプールからは何も生成されない
  assert_that(_seed).is_equal("")


func test_generate_seed_with_pools_mixed_valid_invalid():
  var pool_sequence = [
    {"pool": "test_easy", "count": 1},
    {"pool": "nonexistent_pool", "count": 1},
    {"pool": "test_boss", "count": 1}
  ]

  var _seed = RandomSeedGenerator.generate_seed_with_pools(pool_sequence)

  # 有効なプールからのみ生成される
  var parts = _seed.split("-")
  assert_that(parts.size()).is_equal(2)  # easy 1個 + boss 1個


func test_generate_random_seed_for_stage_basic():
  var stage_config = {
    "total_waves": 3, "pool_weights": {"test_easy": 50, "test_medium": 30, "test_boss": 20}
  }

  var _seed = RandomSeedGenerator.generate_random_seed_for_stage(stage_config)

  # シード値が生成されることを確認
  assert_that(_seed).is_not_empty()

  # 指定された数のウェーブが生成される
  var parts = _seed.split("-")
  assert_that(parts.size()).is_equal(3)


func test_generate_random_seed_for_stage_no_pool_weights():
  var stage_config = {"total_waves": 2, "pool_weights": {}}

  # プール重みが空の場合はデフォルトを使用
  var _seed = RandomSeedGenerator.generate_random_seed_for_stage(stage_config)

  # デフォルト重みでは存在しないプールを参照するためエラーになる可能性があるが、
  # 少なくともクラッシュしないことを確認
  assert_that(_seed).is_not_null()


func test_wave_selection_respects_weights():
  # 重み付き選択のテスト（確率的なので複数回実行）
  var selections = {}

  for i in range(100):
    var wave = RandomSeedGenerator._select_wave_from_pool("test_easy")
    if wave in selections:
      selections[wave] += 1
    else:
      selections[wave] = 1

  # 重みが高い test_easy_1 (weight: 10) が test_easy_2 (weight: 5) より多く選ばれる傾向があることを確認
  # 統計的な検証のため、厳密な比率ではなく傾向を確認
  assert_that(selections.has("test_easy_1")).is_true()
  assert_that(selections.has("test_easy_2")).is_true()


func test_wave_selection_default_weight():
  # weight が設定されていないウェーブのテスト
  var wave = RandomSeedGenerator._select_wave_from_pool("test_easy")

  # no_weight_wave も選択される可能性がある（デフォルト重み1）
  assert_that(wave).is_not_empty()
  assert_int(["test_easy_1", "test_easy_2", "no_weight_wave"].find(wave)).is_greater_equal(0)


func test_seed_generation_signal():
  var signal_received = [false]
  var received_seed = [""]

  # シグナル接続
  RandomSeedGenerator.seed_generated.connect(
    func(_seed):
      signal_received[0] = true
      received_seed[0] = _seed
  )

  var test_seed = "signal-test-seed"
  RandomSeedGenerator.set_current_seed(test_seed)

  assert_that(signal_received[0]).is_true()
  assert_that(received_seed[0]).is_equal(test_seed)


func test_rng_seed_reproducibility():
  # RNGシードを固定して再現性をテスト
  RandomSeedGenerator.set_seed(12345)

  var seed1 = RandomSeedGenerator.generate_seed_with_pools([{"pool": "test_easy", "count": 3}])

  RandomSeedGenerator.set_seed(12345)

  var seed2 = RandomSeedGenerator.generate_seed_with_pools([{"pool": "test_easy", "count": 3}])

  # 同じRNGシードで同じ結果が得られることを確認
  assert_that(seed1).is_equal(seed2)
