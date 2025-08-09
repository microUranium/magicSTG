extends GdUnitTestSuite

# シード値生成システムのエッジケース・エラーハンドリングテストスイート

var test_data: Dictionary


func before():
  # 最小限のテストデータ
  test_data = {
    "wave_templates":
    {
      "valid_wave": {"pool": "valid_pool", "weight": 1, "layers": []},
      "zero_weight_wave": {"pool": "valid_pool", "weight": 0, "layers": []},
      "negative_weight_wave": {"pool": "valid_pool", "weight": -5, "layers": []},
      "no_pool_wave": {"weight": 10, "layers": []},
      "no_weight_wave": {"pool": "valid_pool", "layers": []},
      "empty_wave": {}
    },
    "wave_pools": {"valid_pool": {"description": "A valid pool"}, "empty_description_pool": {}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }


func after():
  # テスト後のクリーンアップ
  RandomSeedGenerator.clear_seed()
  GameDataRegistry.reload_data()


func test_gamedata_registry_not_loaded():
  # GameDataRegistryが読み込まれていない状態をシミュレート
  GameDataRegistry._data_loaded = false

  var wave = RandomSeedGenerator._select_wave_from_pool("any_pool")

  # エラーが発生し、空文字列が返される
  assert_that(wave).is_equal("")

  # データを復元
  GameDataRegistry.load_stage_data(test_data)


func test_select_wave_from_empty_pool():
  GameDataRegistry.load_stage_data(test_data)

  var wave = RandomSeedGenerator._select_wave_from_pool("nonexistent_pool")

  # 存在しないプールの場合は警告とともに空文字列が返される
  assert_that(wave).is_equal("")


func test_select_wave_from_pool_with_zero_total_weight():
  # 全ウェーブの重みが0またはマイナスのプール
  var zero_weight_data = {
    "wave_templates":
    {
      "zero_wave1": {"pool": "zero_pool", "weight": 0, "layers": []},
      "zero_wave2": {"pool": "zero_pool", "weight": 0, "layers": []}
    },
    "wave_pools": {"zero_pool": {"description": "Pool with zero weights"}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }

  GameDataRegistry.load_stage_data(zero_weight_data)

  var wave = RandomSeedGenerator._select_wave_from_pool("zero_pool")

  # total_weight <= 0 の場合は最初のウェーブが選択される
  assert_that(wave).is_equal("zero_wave1")


func test_select_wave_negative_weights():
  # 負の重みを持つウェーブのテスト
  var negative_weight_data = {
    "wave_templates":
    {
      "neg_wave1": {"pool": "neg_pool", "weight": -10, "layers": []},
      "neg_wave2": {"pool": "neg_pool", "weight": 5, "layers": []}
    },
    "wave_pools": {"neg_pool": {"description": "Pool with negative weights"}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }

  GameDataRegistry.load_stage_data(negative_weight_data)

  var wave = RandomSeedGenerator._select_wave_from_pool("neg_pool")

  # 負の重みも計算に含まれ、total_weight は -5 となる
  # この場合は最初のウェーブが選択される
  assert_that(wave).is_equal("neg_wave1")


func test_generate_seed_with_empty_pool_sequence():
  GameDataRegistry.load_stage_data(test_data)

  var empty_sequence = []
  var _seed = RandomSeedGenerator.generate_seed_with_pools(empty_sequence)

  # 空の配列の場合は空文字列が生成される
  assert_that(_seed).is_equal("")


func test_generate_seed_with_invalid_pool_sequence():
  GameDataRegistry.load_stage_data(test_data)

  var invalid_sequence = [
    {"pool": "nonexistent_pool", "count": 3}, {"pool": "", "count": 2}, {"count": 1}  # pool キーが無い
  ]

  var _seed = RandomSeedGenerator.generate_seed_with_pools(invalid_sequence)

  # 無効なプール設定は無視され、空文字列が生成される
  assert_that(_seed).is_equal("")


func test_generate_seed_with_mixed_valid_invalid_pools():
  GameDataRegistry.load_stage_data(test_data)

  var mixed_sequence = [
    {"pool": "valid_pool", "count": 1},
    {"pool": "nonexistent_pool", "count": 2},
    {"pool": "valid_pool", "count": 1}
  ]

  var _seed = RandomSeedGenerator.generate_seed_with_pools(mixed_sequence)

  # 有効なプールからの選択のみが含まれる
  var parts = _seed.split("-")
  assert_that(parts.size()).is_equal(2)  # valid_pool から 2個


func test_generate_random_seed_with_empty_pool_weights():
  GameDataRegistry.load_stage_data(test_data)

  var config = {"total_waves": 3, "pool_weights": {}}

  var _seed = RandomSeedGenerator.generate_random_seed_for_stage(config)

  # 空の重み設定の場合はデフォルト重みが使用される
  # デフォルト重みに存在しないプールが含まれる場合、警告が出るが処理は継続
  assert_that(_seed).is_not_null()


func test_generate_random_seed_with_zero_waves():
  GameDataRegistry.load_stage_data(test_data)

  var config = {"total_waves": 0, "pool_weights": {"valid_pool": 10}}

  var _seed = RandomSeedGenerator.generate_random_seed_for_stage(config)

  # total_waves が 0 の場合は空文字列が生成される
  assert_that(_seed).is_equal("")


func test_select_pool_by_weight_with_empty_weights():
  var empty_weights = {}
  var selected_pool = RandomSeedGenerator._select_pool_by_weight(empty_weights)

  # 空の重み辞書の場合は空文字列が返される
  assert_that(selected_pool).is_equal("")


func test_select_pool_by_weight_with_zero_total():
  var zero_weights = {"pool_a": 0, "pool_b": 0}

  var selected_pool = RandomSeedGenerator._select_pool_by_weight(zero_weights)

  # total_weight <= 0 の場合は最初のキーが返される
  assert_that(selected_pool).is_equal("pool_a")


func test_pool_validation_with_malformed_data():
  # wave_pools に存在しないプールを参照するウェーブ
  var malformed_data = {
    "wave_templates":
    {
      "wave1": {"pool": "existing_pool", "layers": []},
      "wave2": {"pool": "missing_pool", "layers": []},
      "wave3": {"pool": "", "layers": []},  # 空文字列プール
      "wave4": {"layers": []}  # プール指定なし
    },
    "wave_pools": {"existing_pool": {"description": "This exists"}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }

  GameDataRegistry.load_stage_data(malformed_data)

  var is_valid = GameDataRegistry.validate_pool_waves()

  # missing_pool が存在しないため検証は失敗
  assert_that(is_valid).is_false()


func test_rng_boundary_conditions():
  GameDataRegistry.load_stage_data(test_data)

  # 極端な重み値でのテスト
  var extreme_data = {
    "wave_templates":
    {
      "max_weight": {"pool": "extreme_pool", "weight": 2147483647, "layers": []},  # 32bit int の最大値
      "min_weight": {"pool": "extreme_pool", "weight": 1, "layers": []}
    },
    "wave_pools": {"extreme_pool": {"description": "Extreme weights"}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }

  GameDataRegistry.load_stage_data(extreme_data)

  var wave = RandomSeedGenerator._select_wave_from_pool("extreme_pool")

  # オーバーフローせずに選択が行われる
  assert_int(["max_weight", "min_weight"].find(wave)).is_greater_equal(0)


func test_concurrent_seed_generation():
  GameDataRegistry.load_stage_data(test_data)

  # 複数のシード生成を連続で実行
  var seeds = []
  for i in range(5):
    var _seed = RandomSeedGenerator.generate_seed_with_pools([{"pool": "valid_pool", "count": 2}])
    seeds.append(_seed)

  # 各シード生成が独立して動作する
  for _seed in seeds:
    assert_that(_seed).is_not_empty()

  # 現在のシードは最後に生成されたものになる
  assert_that(RandomSeedGenerator.get_current_seed()).is_equal(seeds[-1])


func test_memory_cleanup_after_operations():
  GameDataRegistry.load_stage_data(test_data)

  # 大量のシード生成操作
  for i in range(100):
    RandomSeedGenerator.generate_seed_with_pools([{"pool": "valid_pool", "count": 1}])

  RandomSeedGenerator.clear_seed()

  # メモリリークがないことを確認（現在のシードがクリアされる）
  assert_that(RandomSeedGenerator.get_current_seed()).is_equal("")


func test_json_data_corruption_handling():
  # 不正な形式のデータでのテスト
  var corrupted_data = {
    "wave_templates":
    {
      "valid_wave": {"pool": "valid_pool", "weight": 1, "layers": []},
      "invalid_weight_string": {"pool": "valid_pool", "weight": "not_a_number", "layers": []},
      "invalid_weight_null": {"pool": "valid_pool", "weight": null, "layers": []},
      "invalid_layers": {"pool": "valid_pool", "weight": 1, "layers": "not_an_array"}
    },
    "wave_pools": {"valid_pool": {"description": "Valid pool"}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }

  GameDataRegistry.load_stage_data(corrupted_data)

  # 不正なデータがあってもクラッシュしない
  var wave = RandomSeedGenerator._select_wave_from_pool("valid_pool")
  assert_that(wave).is_not_empty()

  # 重み計算で不正な値は適切に処理される
  # "not_a_number" は get("weight", 1) でデフォルト値 1 に、
  # null も同様にデフォルト値 1 になる
  var seeds = []
  for i in range(10):
    var generated_seed = RandomSeedGenerator.generate_seed_with_pools(
      [{"pool": "valid_pool", "count": 1}]
    )
    seeds.append(generated_seed)

  # 全ての生成が成功する
  for generated_seed in seeds:
    assert_that(generated_seed).is_not_empty()
