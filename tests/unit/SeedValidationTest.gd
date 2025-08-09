extends GdUnitTestSuite

# シード値解析・検証テストスイート

var test_data: Dictionary
var stage_controller: StageController


func before():
  # テスト用のモックデータを準備
  test_data = {
    "wave_templates":
    {"test_wave1": {"layers": []}, "test_wave2": {"layers": []}, "boss_wave": {"layers": []}},
    "dialogues":
    {
      "test_dialogue":
      {
        "intro": [{"speaker_name": "Test", "text": "Hello"}],
        "resolution": [{"speaker_name": "Test", "text": "Goodbye"}]
      }
    },
    "wave_pools": {},
    "enemies": {},
    "spawn_patterns": {}
  }

  GameDataRegistry.load_stage_data(test_data)

  # StageControllerのインスタンスを作成（テスト用）
  stage_controller = StageController.new()


func before_test():
  stage_controller._event_queue.clear()  # イベントキューをクリア


func after():
  # テスト後のクリーンアップ
  GameDataRegistry.reload_data()
  if stage_controller:
    stage_controller.queue_free()


func test_parse_seed_single_wave():
  var _seed = "test_wave1"
  var success = stage_controller._parse_seed(_seed)

  assert_that(success).is_true()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(1)
  assert_that(event_queue[0].get("type", "")).is_equal("wave")
  assert_that(event_queue[0].get("template_name", "")).is_equal("test_wave1")


func test_parse_seed_multiple_waves():
  var _seed = "test_wave1-test_wave2-boss_wave"
  var success = stage_controller._parse_seed(_seed)

  assert_that(success).is_true()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(3)

  for i in range(3):
    assert_that(event_queue[i].get("type", "")).is_equal("wave")

  assert_that(event_queue[0].get("template_name", "")).is_equal("test_wave1")
  assert_that(event_queue[1].get("template_name", "")).is_equal("test_wave2")
  assert_that(event_queue[2].get("template_name", "")).is_equal("boss_wave")


func test_parse_seed_dialogue_format():
  var _seed = "Dtest_dialogue.intro-test_wave1-Dtest_dialogue.resolution"
  var success = stage_controller._parse_seed(_seed)

  assert_that(success).is_true()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(3)

  # 最初のイベントはダイアログ
  assert_that(event_queue[0].get("type", "")).is_equal("dialogue")
  assert_that(event_queue[0].get("dialogue_path", "")).is_equal("test_dialogue.intro")

  # 2番目のイベントはウェーブ
  assert_that(event_queue[1].get("type", "")).is_equal("wave")
  assert_that(event_queue[1].get("template_name", "")).is_equal("test_wave1")

  # 3番目のイベントはダイアログ
  assert_that(event_queue[2].get("type", "")).is_equal("dialogue")
  assert_that(event_queue[2].get("dialogue_path", "")).is_equal("test_dialogue.resolution")


func test_parse_seed_empty_seed():
  var _seed = ""
  var success = stage_controller._parse_seed(_seed)

  assert_that(success).is_false()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(0)


func test_parse_seed_whitespace_handling():
  var _seed = " test_wave1 - test_wave2 "
  var success = stage_controller._parse_seed(_seed)

  assert_that(success).is_true()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(2)
  assert_that(event_queue[0].get("template_name", "")).is_equal("test_wave1")
  assert_that(event_queue[1].get("template_name", "")).is_equal("test_wave2")


func test_parse_seed_invalid_wave_template():
  var _seed = "nonexistent_wave-test_wave1"
  var success = stage_controller._parse_seed(_seed)

  # 無効なテンプレートは警告を出すが、有効なテンプレートは処理される
  assert_that(success).is_true()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(1)  # 有効な test_wave1 のみ
  assert_that(event_queue[0].get("template_name", "")).is_equal("test_wave1")


func test_parse_seed_invalid_dialogue():
  var _seed = "Dnonexistent.dialogue-test_wave1"
  var success = stage_controller._parse_seed(_seed)

  # 無効なダイアログは警告を出すが、有効なウェーブは処理される
  assert_that(success).is_true()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(1)  # 有効な test_wave1 のみ
  assert_that(event_queue[0].get("template_name", "")).is_equal("test_wave1")


func test_parse_seed_malformed_dialogue():
  var _seed = "Dinvalid_format-test_wave1"  # ダイアログ形式が不正（pool.dialogue_id形式でない）
  var success = stage_controller._parse_seed(_seed)

  assert_that(success).is_true()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(1)  # 有効な test_wave1 のみ
  assert_that(event_queue[0].get("template_name", "")).is_equal("test_wave1")


func test_parse_seed_all_invalid():
  var _seed = "nonexistent1-nonexistent2-Dinvalid.format"
  var success = stage_controller._parse_seed(_seed)

  # 全て無効な場合はfalseが返される
  assert_that(success).is_false()

  var event_queue = stage_controller._event_queue
  assert_that(event_queue.size()).is_equal(0)


func test_generated_seed_validity():
  # RandomSeedGeneratorで生成されたシード値の妥当性をテスト
  var pool_sequence = [{"pool": "stage1", "count": 2}, {"pool": "stage1_boss", "count": 1}]

  var generated_seed = RandomSeedGenerator.generate_seed_with_pools(pool_sequence)

  # 実際のstage_data.jsonを使用してシード値をパース
  GameDataRegistry.reload_data()  # 実際のデータを読み込み

  var success = stage_controller._parse_seed(generated_seed)

  # 生成されたシード値が正常にパースされることを確認
  # stage_data.jsonにstage1プールにウェーブが存在すれば成功するはず
  if not generated_seed.is_empty():
    assert_that(success).is_true()


func test_fixed_seed_validity():
  # TitleScreenで使用される固定シード値の妥当性をテスト
  var fixed_seeds = [
    "Ds1d11.intro-s111-s112-s131-s1g1-Ds1d11.progression-s121-s1g1-s112-s141-s112-s1z1-Ds1d11.resolution",
    "Ds1d12.intro-s113-s122-s1g3-s113-s142-Ds1d12.progression-s134-s1g2-s1g4-s1g3-s1g5-s1z3-s1z2-Ds1d12.resolution"
  ]

  GameDataRegistry.reload_data()  # 実際のデータを読み込み

  for _seed in fixed_seeds:
    var success = stage_controller._parse_seed(_seed)
    assert_that(success).is_true()

    var event_queue = stage_controller._event_queue
    assert_that(event_queue.size()).is_greater(0)


func test_seed_format_patterns():
  # 様々なシード値形式のテスト
  var test_cases = [
    {"seed": "single_wave", "expected_events": 1},
    {"seed": "wave1-wave2", "expected_events": 2},
    {"seed": "Ddialogue.test", "expected_events": 1},
    {"seed": "wave1-Ddialogue.test-wave2", "expected_events": 3}
  ]

  for case in test_cases:
    stage_controller._event_queue.clear()

    # テスト用に簡単なデータで実行
    var simple_data = {
      "wave_templates":
      {"single_wave": {"layers": []}, "wave1": {"layers": []}, "wave2": {"layers": []}},
      "dialogues": {"dialogue": {"test": [{"speaker_name": "Test", "text": "Hello"}]}},
      "wave_pools": {},
      "enemies": {},
      "spawn_patterns": {}
    }

    GameDataRegistry.load_stage_data(simple_data)

    var success = stage_controller._parse_seed(case.seed)

    if case.expected_events > 0:
      assert_that(success).is_true()
      assert_that(stage_controller._event_queue.size()).is_equal(case.expected_events)


func test_stage_manager_seed_preparation():
  # StageManagerのシード値準備処理をテスト
  var stage_manager = StageManager.new()

  # シード値を設定してテスト
  RandomSeedGenerator.set_current_seed("test-seed-value")
  stage_manager.stage_seed = ""  # Inspector値を空に

  stage_manager._prepare_stage_seed()

  # RandomSeedGeneratorからの値が使用される
  assert_that(stage_manager.stage_seed).is_equal("test-seed-value")

  # テスト後のクリーンアップ
  stage_manager.queue_free()
  RandomSeedGenerator.clear_seed()
