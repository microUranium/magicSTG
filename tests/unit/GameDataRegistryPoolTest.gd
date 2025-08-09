extends GdUnitTestSuite

# GameDataRegistry のプール機能テストスイート

var test_data: Dictionary


func before():
  # テスト用のモックデータを準備
  test_data = {
    "wave_templates":
    {
      "pool_a_wave1": {"pool": "pool_a", "weight": 10, "layers": []},
      "pool_a_wave2": {"pool": "pool_a", "weight": 5, "layers": []},
      "pool_b_wave1": {"pool": "pool_b", "weight": 8, "layers": []},
      "pool_b_wave2": {"pool": "pool_b", "weight": 3, "layers": []},
      "no_pool_wave": {"weight": 7, "layers": []},
      "no_weight_wave": {"pool": "pool_a", "layers": []},
      "invalid_pool_wave": {"pool": "nonexistent_pool", "weight": 5, "layers": []}
    },
    "wave_pools":
    {
      "pool_a": {"description": "Test pool A"},
      "pool_b": {"description": "Test pool B"},
      "empty_pool": {"description": "Pool with no waves"}
    },
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }


func after():
  # テスト後のクリーンアップ
  GameDataRegistry.reload_data()


func test_load_wave_pools_data():
  GameDataRegistry.load_stage_data(test_data)

  # プールデータが正しく読み込まれることを確認
  assert_that(GameDataRegistry.wave_pools.size()).is_equal(3)
  assert_that(GameDataRegistry.wave_pools.has("pool_a")).is_true()
  assert_that(GameDataRegistry.wave_pools.has("pool_b")).is_true()
  assert_that(GameDataRegistry.wave_pools.has("empty_pool")).is_true()


func test_get_waves_by_pool_valid_pool():
  GameDataRegistry.load_stage_data(test_data)

  var pool_a_waves = GameDataRegistry.get_waves_by_pool("pool_a")

  # pool_a に属するウェーブが正しく取得される
  assert_that(pool_a_waves.size()).is_equal(3)  # pool_a_wave1, pool_a_wave2, no_weight_wave
  assert_that(pool_a_waves.has("pool_a_wave1")).is_true()
  assert_that(pool_a_waves.has("pool_a_wave2")).is_true()
  assert_that(pool_a_waves.has("no_weight_wave")).is_true()


func test_get_waves_by_pool_valid_pool_b():
  GameDataRegistry.load_stage_data(test_data)

  var pool_b_waves = GameDataRegistry.get_waves_by_pool("pool_b")

  # pool_b に属するウェーブが正しく取得される
  assert_that(pool_b_waves.size()).is_equal(2)  # pool_b_wave1, pool_b_wave2
  assert_that(pool_b_waves.has("pool_b_wave1")).is_true()
  assert_that(pool_b_waves.has("pool_b_wave2")).is_true()


func test_get_waves_by_pool_empty_pool():
  GameDataRegistry.load_stage_data(test_data)

  var empty_pool_waves = GameDataRegistry.get_waves_by_pool("empty_pool")

  # empty_pool に属するウェーブは存在しない
  assert_that(empty_pool_waves.size()).is_equal(0)


func test_get_waves_by_pool_nonexistent_pool():
  GameDataRegistry.load_stage_data(test_data)

  var nonexistent_waves = GameDataRegistry.get_waves_by_pool("nonexistent")

  # 存在しないプール名の場合は空の辞書が返される
  assert_that(nonexistent_waves.size()).is_equal(0)


func test_get_waves_by_pool_no_pool_attribute():
  GameDataRegistry.load_stage_data(test_data)

  var no_pool_waves = GameDataRegistry.get_waves_by_pool("")

  # pool属性が空文字列のウェーブを検索
  assert_that(no_pool_waves.size()).is_equal(1)  # no_pool_wave
  assert_that(no_pool_waves.has("no_pool_wave")).is_true()


func test_get_wave_pool_info_valid():
  GameDataRegistry.load_stage_data(test_data)

  var pool_info = GameDataRegistry.get_wave_pool_info("pool_a")

  # プール情報が正しく取得される
  assert_that(pool_info).is_not_empty()
  assert_that(pool_info.get("description", "")).is_equal("Test pool A")


func test_get_wave_pool_info_invalid():
  GameDataRegistry.load_stage_data(test_data)

  var pool_info = GameDataRegistry.get_wave_pool_info("nonexistent")

  # 存在しないプールの場合は空の辞書が返される
  assert_that(pool_info).is_empty()


func test_get_all_pool_names():
  GameDataRegistry.load_stage_data(test_data)

  var pool_names = GameDataRegistry.get_all_pool_names()

  # 全プール名が正しく取得される
  assert_int(pool_names.size()).is_equal(3)
  assert_int(pool_names.find("pool_a")).is_greater_equal(0)
  assert_int(pool_names.find("pool_b")).is_greater_equal(0)
  assert_int(pool_names.find("empty_pool")).is_greater_equal(0)


func test_validate_pool_waves_all_valid():
  # 全て有効な設定のテストデータ
  var valid_data = {
    "wave_templates":
    {
      "wave1": {"pool": "pool_a", "weight": 10, "layers": []},
      "wave2": {"pool": "pool_b", "weight": 5, "layers": []},
      "wave3": {"layers": []}  # プール指定なし（有効）
    },
    "wave_pools": {"pool_a": {"description": "Pool A"}, "pool_b": {"description": "Pool B"}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }

  GameDataRegistry.load_stage_data(valid_data)

  var is_valid = GameDataRegistry.validate_pool_waves()
  assert_that(is_valid).is_true()


func test_validate_pool_waves_invalid_pool_reference():
  # 存在しないプールを参照するテストデータ
  var invalid_data = {
    "wave_templates":
    {
      "wave1": {"pool": "pool_a", "weight": 10, "layers": []},
      "wave2": {"pool": "nonexistent_pool", "weight": 5, "layers": []}
    },
    "wave_pools": {"pool_a": {"description": "Pool A"}},
    "enemies": {},
    "spawn_patterns": {},
    "dialogues": {}
  }

  GameDataRegistry.load_stage_data(invalid_data)

  var is_valid = GameDataRegistry.validate_pool_waves()
  assert_that(is_valid).is_false()


func test_wave_weight_handling():
  GameDataRegistry.load_stage_data(test_data)

  var pool_a_waves = GameDataRegistry.get_waves_by_pool("pool_a")

  # 重み情報が正しく保持されている
  assert_that(pool_a_waves["pool_a_wave1"].get("weight", 1)).is_equal(10)
  assert_that(pool_a_waves["pool_a_wave2"].get("weight", 1)).is_equal(5)
  assert_that(pool_a_waves["no_weight_wave"].get("weight", 1)).is_equal(1)  # デフォルト値


func test_data_consistency_after_multiple_operations():
  GameDataRegistry.load_stage_data(test_data)

  # 複数の操作を実行
  var pool_a_waves = GameDataRegistry.get_waves_by_pool("pool_a")
  var pool_info = GameDataRegistry.get_wave_pool_info("pool_a")
  var all_pools = GameDataRegistry.get_all_pool_names()
  var validation = GameDataRegistry.validate_pool_waves()

  # データの整合性が保たれている
  assert_int(pool_a_waves.size()).is_greater(0)
  assert_that(pool_info).is_not_empty()
  assert_int(all_pools.find("pool_a")).is_greater_equal(0)
  assert_that(validation).is_false()  # invalid_pool_wave が存在するため


func test_empty_data_handling():
  var empty_data = {
    "wave_templates": {}, "wave_pools": {}, "enemies": {}, "spawn_patterns": {}, "dialogues": {}
  }

  GameDataRegistry.load_stage_data(empty_data)

  # 空データでもクラッシュしない
  assert_that(GameDataRegistry.get_waves_by_pool("any_pool").size()).is_equal(0)
  assert_that(GameDataRegistry.get_all_pool_names().size()).is_equal(0)
  assert_that(GameDataRegistry.validate_pool_waves()).is_true()  # 矛盾がないため有効


func test_reload_data_clears_pools():
  GameDataRegistry.load_stage_data(test_data)

  # データが読み込まれていることを確認
  assert_that(GameDataRegistry.wave_pools.size()).is_greater(0)

  # リロード実行
  GameDataRegistry.reload_data()

  # 元のstage_data.jsonが読み込まれる（テストデータはクリアされる）
  # プールデータの内容は実際のJSONファイルによって決まる
  assert_that(GameDataRegistry.wave_pools).is_not_null()
