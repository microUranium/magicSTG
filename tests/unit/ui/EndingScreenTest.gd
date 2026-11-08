# === エンディング画面テスト ===
extends GdUnitTestSuite

const EndingScreenScene = preload("res://scenes/ui/ending_screen.tscn")

var _screen: CanvasLayer
var _finished_count := 0


func before_test() -> void:
  _finished_count = 0
  _screen = EndingScreenScene.instantiate()
  _screen.fade_duration = 0.1
  _screen.finished.connect(func(): _finished_count += 1)
  add_child(_screen)
  await await_idle_frame()


func after_test() -> void:
  if is_instance_valid(_screen):
    _screen.queue_free()


func test_drawn_in_front_of_all_layers() -> void:
  # PauseLayer(100) より前面
  assert_int(_screen.layer).is_greater(100)


func test_background_blocks_mouse_input() -> void:
  var bg := _screen.get_node("Background") as TextureRect
  assert_int(bg.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
  assert_object(bg.texture).is_not_null()


func test_fades_in_from_transparent() -> void:
  var bg := _screen.get_node("Background") as TextureRect
  assert_float(bg.modulate.a).is_less(1.0)

  await await_millis(300)

  assert_float(bg.modulate.a).is_equal_approx(1.0, 0.001)


func test_click_ignored_during_fade_in() -> void:
  _screen._on_background_gui_input(_left_click())

  assert_int(_finished_count).is_equal(0)


func test_click_after_fade_in_emits_finished_once() -> void:
  await await_millis(300)

  _screen._on_background_gui_input(_left_click())
  _screen._on_background_gui_input(_left_click())

  assert_int(_finished_count).is_equal(1)


func test_non_left_click_ignored() -> void:
  await await_millis(300)

  var right := _left_click()
  right.button_index = MOUSE_BUTTON_RIGHT
  _screen._on_background_gui_input(right)
  var release := _left_click()
  release.pressed = false
  _screen._on_background_gui_input(release)

  assert_int(_finished_count).is_equal(0)


func _left_click() -> InputEventMouseButton:
  var ev := InputEventMouseButton.new()
  ev.button_index = MOUSE_BUTTON_LEFT
  ev.pressed = true
  return ev
