# シーン遷移フェード（SceneTransition / GameFlow）の単体テスト
extends GdUnitTestSuite

const SceneTransitionScript := preload("res://scripts/ui/SceneTransition.gd")

var _transition: SceneTransitionScript


func before_test() -> void:
  _transition = auto_free(SceneTransitionScript.new())
  add_child(_transition)


#---------------------------------------------------------------------
# SceneTransition
#---------------------------------------------------------------------
func test_initial_state_is_transparent_and_not_blocking() -> void:
  assert_bool(_transition.is_black()).is_false()
  assert_bool(_transition.is_blocking_input()).is_false()
  assert_bool(_transition.get_node("FadeRect").visible).is_false()


func test_draws_above_pause_layer_and_runs_while_paused() -> void:
  assert_int(_transition.layer).is_greater(100)  # stage_root の PauseLayer(100) より手前
  assert_int(_transition.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_fade_out_and_in_immediately() -> void:
  var rect: ColorRect = _transition.get_node("FadeRect")

  await _transition.fade_out(0.0)
  assert_bool(_transition.is_black()).is_true()
  assert_bool(_transition.is_blocking_input()).is_true()
  assert_bool(rect.visible).is_true()
  assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

  await _transition.fade_in(0.0)
  assert_bool(_transition.is_black()).is_false()
  assert_bool(_transition.is_blocking_input()).is_false()
  assert_bool(rect.visible).is_false()
  assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_fade_out_blocks_input_from_start_and_completes() -> void:
  _transition.fade_out(0.1)
  # 暗転し切る前から入力はブロックされる
  assert_bool(_transition.is_blocking_input()).is_true()
  assert_bool(_transition.is_black()).is_false()

  await await_millis(250)
  assert_bool(_transition.is_black()).is_true()


func test_fade_in_keeps_blocking_until_complete() -> void:
  await _transition.fade_out(0.0)

  _transition.fade_in(0.1)
  assert_bool(_transition.is_blocking_input()).is_true()

  await await_millis(250)
  assert_bool(_transition.is_black()).is_false()
  assert_bool(_transition.is_blocking_input()).is_false()


#---------------------------------------------------------------------
# GameFlow
#---------------------------------------------------------------------
func test_game_flow_owns_scene_transition_layer() -> void:
  var layer := GameFlow.get_node_or_null("SceneTransition")
  assert_object(layer).is_not_null()
  assert_bool(layer is SceneTransitionScript).is_true()
  assert_bool(GameFlow.is_transitioning()).is_false()


func test_game_flow_fade_durations() -> void:
  assert_float(GameFlow.TRANSITION_FADE_OUT).is_equal(0.5)
  assert_float(GameFlow.TRANSITION_FADE_IN).is_equal(0.3)


func test_game_flow_ignores_requests_while_transitioning() -> void:
  var layer: SceneTransitionScript = GameFlow.get_node("SceneTransition")
  GameFlow._is_transitioning = true

  GameFlow.start_equipment_screen()

  # 遷移中は新たなフェードアウトを始めない
  assert_bool(layer.is_blocking_input()).is_false()
  GameFlow._is_transitioning = false
