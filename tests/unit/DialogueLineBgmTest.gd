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
