# ButtonFeedback（押下アニメーション＋クリック音）と ButtonFeedbackInstaller の単体テスト
extends GdUnitTestSuite
class_name ButtonFeedbackTest

const SETTLE_MS := 300  # 押下→離す のアニメーションが終わるまでの待ち時間

var _root: Control
var _sfx_log: Array[String] = []


func before_test() -> void:
  _sfx_log.clear()
  StageSignals.sfx_play_requested.connect(_on_sfx_requested)
  _root = Control.new()
  add_child(_root)


func after_test() -> void:
  StageSignals.sfx_play_requested.disconnect(_on_sfx_requested)
  if _root:
    _root.queue_free()


func _on_sfx_requested(sfx_name: String, _pos: Vector2, _vol: float, _pitch: float) -> void:
  _sfx_log.append(sfx_name)


func _make_button(button_scale := Vector2.ONE) -> Button:
  var button := Button.new()
  button.set_meta(&"no_button_feedback", true)  # 自動付与を避け、テストで明示的に付ける
  button.position = Vector2(100, 100)
  button.size = Vector2(80, 40)
  button.scale = button_scale
  _root.add_child(button)
  return button


func _mouse_button(pressed: bool, local_pos: Vector2) -> InputEventMouseButton:
  var event := InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  event.position = local_pos
  return event


#---------------------------------------------------------------------
# BaseButton
#---------------------------------------------------------------------
func test_press_shrinks_button() -> void:
  var button := _make_button()
  ButtonFeedback.attach(button)

  button.button_down.emit()
  await await_millis(100)

  assert_float(button.scale.x).is_less(1.0)
  assert_float(button.scale.x).is_equal_approx(ButtonFeedback.PRESS_SCALE, 0.001)


func test_release_overshoots_then_returns_to_base() -> void:
  var button := _make_button()
  ButtonFeedback.attach(button)

  button.button_down.emit()
  await await_millis(100)
  button.pressed.emit()
  button.button_up.emit()

  # 膨らむ途中で元より大きくなる
  await await_millis(int(ButtonFeedback.RELEASE_GROW_DURATION * 1000) + 10)
  assert_float(button.scale.x).is_greater(1.0)

  await await_millis(SETTLE_MS)
  assert_vector(button.scale).is_equal(Vector2.ONE)


func test_click_plays_click_sfx() -> void:
  var button := _make_button()
  ButtonFeedback.attach(button)

  button.button_down.emit()
  button.pressed.emit()
  button.button_up.emit()

  assert_array(_sfx_log).contains_exactly(["ui_click"])


func test_release_outside_cancels_without_sfx() -> void:
  var button := _make_button()
  ButtonFeedback.attach(button)

  button.button_down.emit()
  await await_millis(100)
  button.button_up.emit()  # pressed は発火しない = ボタンの外で離した

  assert_array(_sfx_log).is_empty()
  await await_millis(SETTLE_MS)
  assert_vector(button.scale).is_equal(Vector2.ONE)


func test_pressed_after_button_up_still_counts_as_click() -> void:
  var button := _make_button()
  ButtonFeedback.attach(button)

  button.button_down.emit()
  button.button_up.emit()
  button.pressed.emit()

  assert_array(_sfx_log).contains_exactly(["ui_click"])


func test_empty_click_sfx_is_silent() -> void:
  var button := _make_button()
  ButtonFeedback.attach(button, "")

  button.button_down.emit()
  button.pressed.emit()
  button.button_up.emit()

  assert_array(_sfx_log).is_empty()


func test_animation_keeps_base_scale_of_scaled_button() -> void:
  var button := _make_button(Vector2(2, 2))
  ButtonFeedback.attach(button)

  button.button_down.emit()
  await await_millis(100)
  assert_float(button.scale.x).is_equal_approx(2.0 * ButtonFeedback.PRESS_SCALE, 0.001)

  button.pressed.emit()
  button.button_up.emit()
  await await_millis(SETTLE_MS)
  assert_vector(button.scale).is_equal(Vector2(2, 2))


func test_center_pivot_keeps_visual_position_of_scaled_button() -> void:
  var button := _make_button(Vector2(2, 2))
  var center_before := button.get_global_transform() * (button.size / 2.0)
  var corner_before := button.get_global_transform() * Vector2.ZERO

  ButtonFeedback.attach(button)
  await await_idle_frame()  # pivot は遅延で設定される

  assert_vector(button.pivot_offset).is_equal(button.size / 2.0)
  assert_vector(button.get_global_transform() * (button.size / 2.0)).is_equal_approx(
    center_before, Vector2(0.01, 0.01)
  )
  assert_vector(button.get_global_transform() * Vector2.ZERO).is_equal_approx(
    corner_before, Vector2(0.01, 0.01)
  )


func test_custom_target_is_scaled_instead_of_trigger() -> void:
  var button := _make_button()
  var visual := Control.new()
  _root.add_child(visual)
  ButtonFeedback.attach(button, ButtonFeedback.DEFAULT_CLICK_SFX, visual)

  button.button_down.emit()
  await await_millis(100)

  assert_float(visual.scale.x).is_less(1.0)
  assert_vector(button.scale).is_equal(Vector2.ONE)


func test_hiding_trigger_resets_scale() -> void:
  var button := _make_button()
  ButtonFeedback.attach(button)
  button.button_down.emit()
  await await_millis(100)

  button.visible = false

  assert_vector(button.scale).is_equal(Vector2.ONE)


#---------------------------------------------------------------------
# 疑似ボタン（Label＋ClickArea）
#---------------------------------------------------------------------
func test_pseudo_button_emits_pressed_on_release_inside() -> void:
  var area := Control.new()
  area.size = Vector2(50, 50)
  _root.add_child(area)
  var feedback := ButtonFeedback.attach(area)
  var emitter := monitor_signals(feedback)

  area.gui_input.emit(_mouse_button(true, Vector2(10, 10)))
  await assert_signal(emitter).wait_until(50).is_not_emitted("pressed")

  area.gui_input.emit(_mouse_button(false, Vector2(10, 10)))
  await assert_signal(emitter).wait_until(50).is_emitted("pressed")
  assert_array(_sfx_log).contains_exactly(["ui_click"])


func test_pseudo_button_release_outside_does_not_emit() -> void:
  var area := Control.new()
  area.size = Vector2(50, 50)
  _root.add_child(area)
  var feedback := ButtonFeedback.attach(area)
  var emitter := monitor_signals(feedback)

  area.gui_input.emit(_mouse_button(true, Vector2(10, 10)))
  area.gui_input.emit(_mouse_button(false, Vector2(80, 80)))

  await assert_signal(emitter).wait_until(50).is_not_emitted("pressed")
  assert_array(_sfx_log).is_empty()


func test_pseudo_button_hover_and_press_combine() -> void:
  var area := Control.new()
  area.size = Vector2(50, 50)
  _root.add_child(area)
  var label := Label.new()
  _root.add_child(label)
  var feedback := ButtonFeedback.attach(area, ButtonFeedback.DEFAULT_CLICK_SFX, label)
  feedback.hover_scale = 1.1
  feedback.hover_sfx = ButtonFeedback.DEFAULT_HOVER_SFX

  area.mouse_entered.emit()
  await await_millis(250)
  assert_float(label.scale.x).is_equal_approx(1.1, 0.001)
  assert_array(_sfx_log).contains_exactly(["ui_hover"])

  area.gui_input.emit(_mouse_button(true, Vector2(10, 10)))
  await await_millis(100)
  assert_float(label.scale.x).is_equal_approx(1.1 * ButtonFeedback.PRESS_SCALE, 0.001)

  area.gui_input.emit(_mouse_button(false, Vector2(10, 10)))
  await await_millis(SETTLE_MS)
  assert_float(label.scale.x).is_equal_approx(1.1, 0.001)

  area.mouse_exited.emit()
  await await_millis(250)
  assert_float(label.scale.x).is_equal_approx(1.0, 0.001)


#---------------------------------------------------------------------
# ButtonFeedbackInstaller（autoload）
#---------------------------------------------------------------------
func test_installer_attaches_to_new_buttons() -> void:
  var button := Button.new()
  _root.add_child(button)
  await await_idle_frame()

  assert_object(ButtonFeedback.find_on(button)).is_not_null()


func test_installer_respects_opt_out_meta() -> void:
  var button := _make_button()
  await await_idle_frame()

  assert_object(ButtonFeedback.find_on(button)).is_null()


func test_installer_keeps_explicit_feedback() -> void:
  var button := Button.new()
  _root.add_child(button)
  var explicit := ButtonFeedback.attach(button, "")
  await await_idle_frame()

  var feedbacks := button.get_children().filter(func(c): return c is ButtonFeedback)
  assert_int(feedbacks.size()).is_equal(1)
  assert_object(feedbacks[0]).is_same(explicit)
