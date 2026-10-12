# セリフ行ごとの BGM 切り替えの単体テスト
extends GdUnitTestSuite

const TEST_BGM_PATH := "res://assets/audio/bgm/stage5_bgm_kari.mp3"

var _requests: Array = []
var _collector: Callable


func before_test():
  _requests.clear()
  _collector = func(stream, fade, volume_db): _requests.append([stream, fade, volume_db])
  StageSignals.bgm_play_requested.connect(_collector)


func after_test():
  if StageSignals.bgm_play_requested.is_connected(_collector):
    StageSignals.bgm_play_requested.disconnect(_collector)


func test_converter_reads_bgm_from_json() -> void:
  var lines := DialogueConverter.convert_json_to_dialogue_lines(
    [
      {"speaker_name": "A", "text": "BGMなし"},
      {
        "speaker_name": "A",
        "text": "ここで曲が変わる",
        "bgm": TEST_BGM_PATH,
        "bgm_volume_db": -10.0,
        "bgm_fade_in": 1.5
      }
    ]
  )

  assert_object(lines[0].bgm).is_null()
  assert_str(lines[1].bgm.resource_path).is_equal(TEST_BGM_PATH)
  assert_float(lines[1].bgm_volume_db).is_equal(-10.0)
  assert_float(lines[1].bgm_fade_in).is_equal(1.5)


func test_converter_ignores_missing_bgm_file() -> void:
  var lines := DialogueConverter.convert_json_to_dialogue_lines(
    [{"speaker_name": "A", "text": "存在しないBGM", "bgm": "res://nonexistent/bgm.mp3"}]
  )

  assert_object(lines[0].bgm).is_null()


func test_converter_reads_sfx_and_flash_from_json() -> void:
  var lines := DialogueConverter.convert_json_to_dialogue_lines(
    [
      {"speaker_name": "A", "text": "演出なし"},
      {
        "speaker_name": "A",
        "text": "ここで雷が鳴る",
        "sfx": "story_thunder",
        "sfx_volume_db": -5.0,
        "flash": 0.3
      }
    ]
  )

  assert_str(lines[0].sfx).is_empty()
  assert_float(lines[0].flash).is_equal(0.0)
  assert_str(lines[1].sfx).is_equal("story_thunder")
  assert_float(lines[1].sfx_volume_db).is_equal(-5.0)
  assert_float(lines[1].flash).is_equal(0.3)


func test_dialogue_runner_plays_line_sfx_and_flash() -> void:
  var runner := DialogueRunner.new()
  add_child(runner)

  var sfx_requests: Array = []
  var flash_requests: Array = []
  var sfx_collector := func(name, _pos, volume_db, _pitch): sfx_requests.append([name, volume_db])
  var flash_collector := func(duration): flash_requests.append(duration)
  StageSignals.sfx_play_requested.connect(sfx_collector)
  StageSignals.request_hud_flash.connect(flash_collector)

  runner._apply_line_effects(DialogueLine.new())
  assert_array(sfx_requests).is_empty()
  assert_array(flash_requests).is_empty()

  var line := DialogueLine.new()
  line.sfx = "story_thunder"
  line.sfx_volume_db = 0.0
  line.flash = 0.3
  runner._apply_line_effects(line)

  assert_array(sfx_requests).is_equal([["story_thunder", 0.0]])
  assert_array(flash_requests).is_equal([0.3])

  StageSignals.sfx_play_requested.disconnect(sfx_collector)
  StageSignals.request_hud_flash.disconnect(flash_collector)
  runner.queue_free()


func test_thunder_sfx_is_registered_in_catalog() -> void:
  var catalog = load("res://assets/SFX/SFX_Catalog.tres")

  assert_bool(catalog.table.has("story_thunder")).is_true()


func test_dialogue_runner_plays_line_bgm() -> void:
  var runner := DialogueRunner.new()
  add_child(runner)

  # BGM 未指定の行では再生要求を出さない
  runner._play_line_bgm(DialogueLine.new())
  assert_array(_requests).is_empty()

  var bgm_line := DialogueLine.new()
  bgm_line.bgm = load(TEST_BGM_PATH)
  bgm_line.bgm_volume_db = -10.0
  bgm_line.bgm_fade_in = 0.0
  runner._play_line_bgm(bgm_line)

  assert_int(_requests.size()).is_equal(1)
  assert_float(_requests[0][1]).is_equal(0.0)
  assert_float(_requests[0][2]).is_equal(-10.0)

  runner.queue_free()
