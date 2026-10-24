# ConfigPanelControllerの単体テスト
extends GdUnitTestSuite
class_name ConfigPanelControllerTest

const CONFIG_PANEL_SCENE := "res://scenes/ui/config_panel.tscn"
const TEST_SETTINGS_PATH := "user://test_config_panel.cfg"

var _panel: ConfigPanelController
var _orig_settings_path: String
var _orig_volumes: Dictionary


func before_test() -> void:
  _orig_settings_path = SettingsManager.settings_path
  _orig_volumes = SettingsManager._volumes.duplicate()
  SettingsManager.settings_path = TEST_SETTINGS_PATH
  _remove_test_settings()
  SettingsManager.load_settings()

  _panel = load(CONFIG_PANEL_SCENE).instantiate()
  add_child(_panel)
  await await_idle_frame()


func after_test() -> void:
  if _panel:
    _panel.queue_free()

  _remove_test_settings()
  SettingsManager.settings_path = _orig_settings_path
  SettingsManager._volumes = _orig_volumes
  SettingsManager._apply_all()
  SettingsManager._dirty = false


#---------------------------------------------------------------------
# Tests
#---------------------------------------------------------------------
func test_initially_hidden() -> void:
  assert_bool(_panel.visible).is_false()
  assert_bool(_panel.is_open()).is_false()


func test_title_label() -> void:
  var label: Label = _panel.get_node("ConfigLabel")
  assert_str(label.text).is_equal("CONFIG")
  assert_object(label.get_theme_font("font")).is_instanceof(FontVariation)


func test_open_shows_panel_and_refreshes_sliders() -> void:
  SettingsManager.set_bus_volume(&"Music", 0.45)

  _panel.open()

  assert_bool(_panel.visible).is_true()
  assert_float(_panel._volume_settings._sliders[&"Music"].value).is_equal_approx(45.0, 0.001)


func test_close_hides_panel_and_emits_closed() -> void:
  var emitter := monitor_signals(_panel)
  _panel.open()

  _panel.close()

  assert_bool(_panel.visible).is_false()
  await assert_signal(emitter).wait_until(50).is_emitted("closed")


func test_close_saves_unsaved_changes() -> void:
  _panel.open()
  SettingsManager.set_bus_volume(&"SFX", 0.2)

  _panel.close()

  assert_bool(SettingsManager.has_unsaved_changes()).is_false()
  assert_bool(FileAccess.file_exists(TEST_SETTINGS_PATH)).is_true()


func test_close_without_changes_does_not_write_file() -> void:
  _panel.open()
  _panel.close()

  assert_bool(FileAccess.file_exists(TEST_SETTINGS_PATH)).is_false()


func test_escape_closes_panel() -> void:
  _panel.open()

  var event := InputEventKey.new()
  event.keycode = KEY_ESCAPE
  event.pressed = true
  _panel._unhandled_input(event)

  assert_bool(_panel.visible).is_false()


func test_escape_ignored_while_hidden() -> void:
  var emitter := monitor_signals(_panel)

  var event := InputEventKey.new()
  event.keycode = KEY_ESCAPE
  event.pressed = true
  _panel._unhandled_input(event)

  await assert_signal(emitter).wait_until(50).is_not_emitted("closed")


func test_back_click_closes_panel() -> void:
  _panel.open()

  var event := InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = true
  _panel._on_back_area_input(event)

  assert_bool(_panel.visible).is_false()


func test_overlay_blocks_input_to_screen_behind() -> void:
  var overlay: ColorRect = _panel.get_node("DarkOverlay")
  assert_int(overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


#---------------------------------------------------------------------
# Helpers
#---------------------------------------------------------------------
func _remove_test_settings() -> void:
  if FileAccess.file_exists(TEST_SETTINGS_PATH):
    DirAccess.remove_absolute(TEST_SETTINGS_PATH)
