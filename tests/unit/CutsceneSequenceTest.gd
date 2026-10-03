# 撃破後演出（CutscenePlayer / ScreenFade / 自機の自動移動）の単体テスト
extends GdUnitTestSuite

const CUTSCENE_HARPY_SCENE := preload("res://scenes/cutscene/cutscene_harpy.tscn")

var _cutscene_player: CutscenePlayer
var _actor_parent: Node2D
var _dialogue_paths: Array[String] = []
var _fade_events: Array = []


func before_test():
  _dialogue_paths.clear()
  _fade_events.clear()

  _actor_parent = Node2D.new()
  add_child(_actor_parent)

  _cutscene_player = CutscenePlayer.new()
  _actor_parent.add_child(_cutscene_player)

  # ダイアログ要求は即座に完了させる（DialogueRunner の代わり）
  StageSignals.request_dialogue.connect(_on_request_dialogue)
  StageSignals.request_screen_fade.connect(_on_request_screen_fade)


func after_test():
  if StageSignals.request_dialogue.is_connected(_on_request_dialogue):
    StageSignals.request_dialogue.disconnect(_on_request_dialogue)
  if StageSignals.request_screen_fade.is_connected(_on_request_screen_fade):
    StageSignals.request_screen_fade.disconnect(_on_request_screen_fade)
  if is_instance_valid(_actor_parent):
    _actor_parent.queue_free()
  _cutscene_player = null


func _on_request_dialogue(_dd, finished_cb: Callable) -> void:
  _dialogue_paths.append("dialogue")
  if finished_cb.is_valid():
    finished_cb.call_deferred()  # DialogueRunner と同様に非同期で完了を返す


func _on_request_screen_fade(to_black: bool, duration: float) -> void:
  _fade_events.append([to_black, duration])


#---------------------------------------------------------------------
# CutscenePlayer
#---------------------------------------------------------------------
func test_spawn_move_and_exit_actor() -> void:
  var steps := [
    {
      "type": "spawn_actor",
      "id": "harpy",
      "scene": "res://scenes/cutscene/cutscene_harpy.tscn",
      "position": [100, 200]
    },
    {"type": "move_actor", "id": "harpy", "position": [300, 200], "time": 0.1},
    {"type": "exit_actor", "id": "harpy", "position": [300, -160], "time": 0.1},
  ]

  var emitter := monitor_signals(_cutscene_player)
  _cutscene_player.play("test", {"steps": steps})

  # spawn_actor は同期実行されるため、移動が始まる前の座標を確認できる
  var actor := _find_actor()
  assert_object(actor).is_not_null()
  assert_vector(actor.global_position).is_equal(Vector2(100, 200))

  await assert_signal(emitter).wait_until(2000).is_emitted("cutscene_finished", ["test"])
  await await_millis(100)
  assert_object(_find_actor()).is_null()


func test_dialogue_and_fade_steps_run_in_order() -> void:
  var steps := [
    {"type": "fade_in", "time": 0.0},
    {"type": "dialogue", "path": "s5d12.resolution2"},
    {"type": "dialogue", "path": "s5d12.resolution3"},
  ]

  var emitter := monitor_signals(_cutscene_player)
  _cutscene_player.play("test", {"steps": steps})
  await assert_signal(emitter).wait_until(2000).is_emitted("cutscene_finished", ["test"])

  assert_int(_dialogue_paths.size()).is_equal(2)
  assert_array(_fade_events).is_equal([[false, 0.0]])


func test_player_control_is_blocked_during_cutscene() -> void:
  var events: Array = []
  var collector := func(paused: bool): events.append(paused)
  StageSignals.cutscene_pause_requested.connect(collector)

  var emitter := monitor_signals(_cutscene_player)
  _cutscene_player.play("test", {"steps": [{"type": "wait", "time": 0.0}]})
  await assert_signal(emitter).wait_until(2000).is_emitted("cutscene_finished", ["test"])

  StageSignals.cutscene_pause_requested.disconnect(collector)
  assert_array(events).is_equal([true, false])


func test_move_player_warps_registered_player() -> void:
  var stub := _StubPlayer.new()
  add_child(stub)
  TargetService.register_player(stub)

  var emitter := monitor_signals(_cutscene_player)
  _cutscene_player.play(
    "test", {"steps": [{"type": "move_player", "position": [448, 748], "time": 0.0}]}
  )
  await assert_signal(emitter).wait_until(2000).is_emitted("cutscene_finished", ["test"])

  assert_vector(stub.moved_to).is_equal(Vector2(448, 748))
  TargetService.unregister_player()
  stub.queue_free()


#---------------------------------------------------------------------
# シードからの演出イベント
#---------------------------------------------------------------------
func test_cutscene_event_is_parsed_from_seed() -> void:
  GameDataRegistry.cutscenes["test_cutscene"] = {"steps": [{"type": "wait", "time": 0.0}]}

  var controller := StageController.new()
  add_child(controller)

  assert_bool(controller.start_stage("Ctest_cutscene")).is_true()
  assert_int(controller.get_total_events()).is_equal(1)

  controller.stop_stage()
  controller.queue_free()
  GameDataRegistry.cutscenes.erase("test_cutscene")


#---------------------------------------------------------------------
# ScreenFade
#---------------------------------------------------------------------
func test_screen_fade_applies_alpha_immediately() -> void:
  var fade := ScreenFade.new()
  var rect := ColorRect.new()
  rect.name = "FadeRect"
  rect.color = Color(0, 0, 0, 0)
  fade.add_child(rect)
  add_child(fade)

  StageSignals.emit_request_screen_fade(true, 0.0)
  assert_bool(fade.is_black()).is_true()
  assert_bool(rect.visible).is_true()

  StageSignals.emit_request_screen_fade(false, 0.0)
  assert_bool(fade.is_black()).is_false()
  assert_bool(rect.visible).is_false()

  fade.queue_free()


#---------------------------------------------------------------------
# 自機の自動移動
#---------------------------------------------------------------------
func test_player_move_to_warps_to_target() -> void:
  var player := preload("res://scenes/player/player.tscn").instantiate()
  add_child(player)
  await await_idle_frame()

  player.move_to(Vector2(448, 748), 0.0)

  assert_vector(player.global_position).is_equal(Vector2(448, 748))
  player.queue_free()


func test_player_stays_outside_play_rect_while_exiting() -> void:
  var player := preload("res://scenes/player/player.tscn").instantiate()
  add_child(player)
  await await_idle_frame()

  # 画面上への退場中は移動範囲制限で引き戻されない
  player.move_to(Vector2(448, -160), 0.0)
  player._process(0.016)

  assert_float(player.global_position.y).is_equal(-160.0)
  player.queue_free()


func test_player_clamp_can_be_restored() -> void:
  var player := preload("res://scenes/player/player.tscn").instantiate()
  add_child(player)
  await await_idle_frame()

  player.move_to(Vector2(448, -160), 0.0)
  player.set_position_clamp_enabled(true)
  player._process(0.016)

  assert_float(player.global_position.y).is_greater(-160.0)
  player.queue_free()


func _find_actor() -> CutsceneActor:
  for child in _actor_parent.get_children():
    if child is CutsceneActor:
      return child
  return null


class _StubPlayer:
  extends Node2D

  var moved_to: Vector2 = Vector2.ZERO

  func move_to(target_position: Vector2, duration: float) -> Tween:
    moved_to = target_position
    global_position = target_position
    return null if duration <= 0.0 else create_tween()
