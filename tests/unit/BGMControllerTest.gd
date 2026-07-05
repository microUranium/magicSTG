extends GdUnitTestSuite

const BGMControllerScript = preload("res://scripts/autoload/BGMController.gd")

var _bgm


func before_test() -> void:
  _bgm = BGMControllerScript.new()
  add_child(_bgm)
  await await_idle_frame()


func after_test() -> void:
  if is_instance_valid(_bgm):
    _bgm.queue_free()


func _make_stream() -> AudioStream:
  # 実データ不要で play() が有効になる軽量ストリーム
  return AudioStreamGenerator.new()


func _other_player():
  return _bgm._a if _bgm._active == _bgm._b else _bgm._b


func test_play_starts_active_player() -> void:
  var s := _make_stream()

  _bgm._on_play_request(s, 0.05, 0.0)
  await await_idle_frame()

  assert_bool(_bgm._active.stream == s).is_true()
  assert_bool(_bgm._active.playing).is_true()


func test_replay_same_stream_after_stop_resumes() -> void:
  # 欠陥Aの回帰: 停止後に同じ曲を要求したら鳴り直す（早期リターンで無音にならない）
  var s := _make_stream()

  _bgm._on_play_request(s, 0.0, 0.0)
  await await_idle_frame()

  _bgm._on_stop_request(0.0)
  await await_millis(50)
  assert_bool(_bgm._active.playing).is_false()  # 一度停止している

  _bgm._on_play_request(s, 0.0, 0.0)  # 同じ曲を再要求
  await await_idle_frame()

  assert_bool(_bgm._active.playing).is_true()
  assert_bool(_bgm._active.stream == s).is_true()


func test_rapid_switch_leaves_only_latest_playing() -> void:
  # 欠陥Bの回帰: 高速な曲切替後、最後の曲だけが鳴り、他方は停止している
  var a := _make_stream()
  var b := _make_stream()

  _bgm._on_play_request(a, 0.1, 0.0)
  _bgm._on_play_request(b, 0.1, 0.0)  # フェード途中で切替

  await await_millis(300)  # 両方のtweenが完了する時間

  assert_bool(_bgm._active.stream == b).is_true()
  assert_bool(_bgm._active.playing).is_true()
  assert_bool(_other_player().playing).is_false()


func test_stop_after_rapid_switch_silences_all() -> void:
  # クロスフェード中断からの停止で、両プレイヤーとも無音になる
  var a := _make_stream()
  var b := _make_stream()

  _bgm._on_play_request(a, 0.2, 0.0)
  _bgm._on_play_request(b, 0.2, 0.0)  # フェード途中で切替
  _bgm._on_stop_request(0.0)  # さらにフェード途中で停止

  await await_millis(100)

  assert_bool(_bgm._a.playing).is_false()
  assert_bool(_bgm._b.playing).is_false()
