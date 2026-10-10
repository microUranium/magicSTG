# 5-3 人形撃破後の演出（フェーズ7〜9）の結合テスト
extends GdUnitTestSuite

const DOLL_SCENE := preload("res://scenes/enemy/enemy_boss_doll.tscn")

var _doll: Node2D
var _player_stub: _StubPlayer
var _dialogue_paths: Array[String] = []
var _fade_events: Array = []


func before_test():
  _dialogue_paths.clear()
  _fade_events.clear()

  _player_stub = _StubPlayer.new()
  add_child(_player_stub)
  TargetService.register_player(_player_stub)

  StageSignals.request_dialogue.connect(_on_request_dialogue)
  StageSignals.request_screen_fade.connect(_on_request_screen_fade)

  _doll = DOLL_SCENE.instantiate()
  add_child(_doll)
  await await_idle_frame()


func after_test():
  if StageSignals.request_dialogue.is_connected(_on_request_dialogue):
    StageSignals.request_dialogue.disconnect(_on_request_dialogue)
  if StageSignals.request_screen_fade.is_connected(_on_request_screen_fade):
    StageSignals.request_screen_fade.disconnect(_on_request_screen_fade)
  TargetService.unregister_player()
  if is_instance_valid(_doll):
    _doll.queue_free()
  if is_instance_valid(_player_stub):
    _player_stub.queue_free()


func _on_request_dialogue(_dd, finished_cb: Callable) -> void:
  if finished_cb.is_valid():
    finished_cb.call_deferred()


func _on_request_screen_fade(to_black: bool, duration: float) -> void:
  _fade_events.append([to_black, duration])


func _track_dialogue_paths() -> void:
  # 会話パスはパターン側に設定されているため、フェーズ定義から読み取る
  for phase_idx in [7, 8, 9]:
    var phase: PhaseResource = _doll.ai.phases[phase_idx]
    for pattern in phase.patterns:
      if not pattern.dialogue_path.is_empty():
        _dialogue_paths.append(pattern.dialogue_path)


func test_cutscene_phases_are_defined_in_order() -> void:
  assert_int(_doll.ai.phases.size()).is_equal(10)

  _track_dialogue_paths()
  assert_array(_dialogue_paths).is_equal(
    ["s5d12.battle_progression3", "s5d12.battle_progression4", "s5d12.resolution1"]
  )


func test_cutscene_runs_from_doll_defeat_to_fade_out(timeout := 20000) -> void:
  var ai = _doll.ai
  ai._phase_idx = 6
  ai._next_phase()  # フェーズ7（撃破後の演出）へ

  # フェーズ7: 人形は画面上中央へ、自機は画面下中央へ自動移動する
  await await_idle_frame()
  assert_vector(_player_stub.last_target).is_equal(Vector2(448, 748))

  # フェーズ8: ハーピーが登場する
  await await_millis(1800)
  assert_int(ai._phase_idx).is_equal(8)
  assert_object(_find_harpy()).is_not_null()

  # battle_progression4 の後、ハーピーと自機が画面上へ退場する
  await await_millis(1200)
  assert_vector(_player_stub.last_target).is_equal(Vector2(448, -160))
  assert_object(_find_harpy()).is_null()

  # 2秒の間を置いて人形が画面上中央へ戻り、フェーズ9へ進む
  await await_millis(5500)
  # フェーズ9: resolution1 の後に暗転し、人形が退場する
  assert_array(_fade_events).is_equal([[true, 0.8]])
  assert_bool(is_instance_valid(_doll)).is_false()
  assert_object(_find_harpy()).is_null()


#---------------------------------------------------------------------
# 5-3 の演出データ
#---------------------------------------------------------------------
func test_stage5_cutscene_data_is_valid() -> void:
  var data := GameDataRegistry.get_cutscene_data("s5c1")
  assert_dict(data).is_not_empty()

  var steps: Array = data.get("steps", [])
  assert_array(steps).is_not_empty()

  for step in steps:
    match step.get("type", ""):
      "dialogue":
        assert_array(GameDataRegistry.get_dialogue_data(step["path"])).is_not_empty()
      "set_background":
        assert_bool(ResourceLoader.exists(step["texture"])).is_true()
      "spawn_actor":
        assert_bool(ResourceLoader.exists(step["scene"])).is_true()


func test_stage5_3_seed_contains_cutscene_event() -> void:
  var controller := StageController.new()
  add_child(controller)

  assert_bool(controller.start_stage("Ds5d12.battle_conversation-s5z2-Cs5c1")).is_true()
  assert_int(controller.get_total_events()).is_equal(3)

  controller.stop_stage()
  controller.queue_free()


func test_battle_progression3_switches_bgm_on_its_line() -> void:
  var dialogue_data := DialogueConverter.get_dialogue_data_from_path("s5d12.battle_progression3")
  assert_object(dialogue_data).is_not_null()

  var bgm_lines: Array[DialogueLine] = []
  for line in dialogue_data.lines:
    if line.bgm != null:
      bgm_lines.append(line)

  assert_int(bgm_lines.size()).is_equal(1)
  assert_str(bgm_lines[0].bgm.resource_path).is_equal("res://assets/audio/bgm/stage5_bgm_kari.mp3")
  assert_float(bgm_lines[0].bgm_volume_db).is_equal(-10.0)  # 5-3 開始時と同じ音量


func _find_harpy() -> CutsceneActor:
  for child in get_children():
    if child is CutsceneActor:
      return child
  return null


class _StubPlayer:
  extends Node2D

  var last_target: Vector2 = Vector2.ZERO

  func move_to(target_position: Vector2, duration: float) -> Tween:
    last_target = target_position
    if duration <= 0.0:
      global_position = target_position
      return null
    var tween := create_tween()
    tween.tween_property(self, "global_position", target_position, duration)
    return tween
