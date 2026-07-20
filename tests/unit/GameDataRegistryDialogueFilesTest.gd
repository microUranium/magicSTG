extends GdUnitTestSuite

# 分割された会話データファイル (resources/data/dialogues/stage*.json) の読み込みテスト


func after():
  # テスト後は実データを再読み込みして他のテストへの影響を防ぐ
  GameDataRegistry.reload_data()


func test_real_load_merges_all_stage_dialogue_files():
  # 引数なし読み込み時、stage1〜6の全プールがマージされる
  var result = GameDataRegistry.load_stage_data()

  assert_that(result).is_true()
  for stage_num in range(1, 7):
    for pool_suffix in ["d11", "d12"]:
      var pool_name = "s%d%s" % [stage_num, pool_suffix]
      (
        assert_that(GameDataRegistry.dialogues.has(pool_name))
        . override_failure_message("Dialogue pool '%s' should be loaded" % pool_name)
        . is_true()
      )


func test_get_dialogue_data_works_with_split_files():
  GameDataRegistry.load_stage_data()

  # 各プールに最低1つの会話があり、パス指定で取得できる
  var pool = GameDataRegistry.dialogues["s1d11"] as Dictionary
  assert_that(pool.is_empty()).is_false()

  var dialogue_id = pool.keys()[0]
  var lines = GameDataRegistry.get_dialogue_data("s1d11.%s" % dialogue_id)
  assert_that(lines.is_empty()).is_false()
  assert_that(lines[0] is Dictionary).is_true()


func test_injected_data_does_not_load_external_files():
  # テスト用にデータを注入した場合、外部ファイルは読み込まれない
  var injected = {
    "stage_configs": {},
    "wave_templates": {},
    "enemies": {},
    "spawn_patterns": {},
    "wave_pools": {},
    "dialogues": {"mock_pool": {"d1": [{"speaker_name": "Test", "text": "Hello"}]}}
  }
  GameDataRegistry.load_stage_data(injected)

  assert_that(GameDataRegistry.dialogues.size()).is_equal(1)
  assert_that(GameDataRegistry.dialogues.has("mock_pool")).is_true()
  assert_that(GameDataRegistry.dialogues.has("s1d11")).is_false()
