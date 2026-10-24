# VolumeSettingsの単体テスト
extends GdUnitTestSuite
class_name VolumeSettingsTest

const VOLUME_SETTINGS_SCENE := "res://scenes/ui/volume_settings.tscn"
const TEST_SETTINGS_PATH := "user://test_volume_settings.cfg"

var _volume_settings: VolumeSettings
var _orig_settings_path: String
var _orig_volumes: Dictionary


func before_test() -> void:
  _orig_settings_path = SettingsManager.settings_path
  _orig_volumes = SettingsManager._volumes.duplicate()
  SettingsManager.settings_path = TEST_SETTINGS_PATH
  _remove_test_settings()
  SettingsManager.load_settings()

  _volume_settings = load(VOLUME_SETTINGS_SCENE).instantiate()
  add_child(_volume_settings)
  await await_idle_frame()


func after_test() -> void:
  if _volume_settings:
    _volume_settings.queue_free()

  _remove_test_settings()
  SettingsManager.settings_path = _orig_settings_path
  SettingsManager._volumes = _orig_volumes
  SettingsManager._apply_all()
  SettingsManager._dirty = false


#---------------------------------------------------------------------
# Tests
#---------------------------------------------------------------------
func test_has_slider_for_each_audio_bus() -> void:
  assert_array(_volume_settings._sliders.keys()).contains_exactly_in_any_order(
    SettingsManager.AUDIO_BUSES
  )


func test_refresh_reflects_current_settings() -> void:
  SettingsManager.set_bus_volume(&"Music", 0.3)

  _volume_settings.refresh()

  var slider: HSlider = _volume_settings._sliders[&"Music"]
  assert_float(slider.value).is_equal_approx(30.0, 0.001)
  assert_str(_volume_settings._value_labels[&"Music"].text).is_equal("30")


func test_refresh_does_not_mark_settings_dirty() -> void:
  _volume_settings.refresh()

  assert_bool(SettingsManager.has_unsaved_changes()).is_false()


func test_slider_change_updates_settings_and_label() -> void:
  var slider: HSlider = _volume_settings._sliders[&"SFX"]

  slider.value = 40.0

  assert_float(SettingsManager.get_bus_volume(&"SFX")).is_equal_approx(0.4, 0.0001)
  assert_str(_volume_settings._value_labels[&"SFX"].text).is_equal("40")
  var idx := AudioServer.get_bus_index(&"SFX")
  assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.4), 0.001)


func test_slider_drag_end_saves_settings() -> void:
  var slider: HSlider = _volume_settings._sliders[&"Master"]
  slider.value = 60.0

  slider.drag_ended.emit(true)

  assert_bool(SettingsManager.has_unsaved_changes()).is_false()
  assert_bool(FileAccess.file_exists(TEST_SETTINGS_PATH)).is_true()


func test_preview_plays_on_sfx_bus() -> void:
  _volume_settings._sliders[&"SFX"].drag_ended.emit(true)

  var player: AudioStreamPlayer = _volume_settings._preview_player
  assert_str(String(player.bus)).is_equal("SFX")
  assert_object(player.stream).is_same(SfxManager.catalog.table["hit_enemy"])


func test_preview_plays_on_ui_bus() -> void:
  _volume_settings._sliders[&"SFX_UI"].drag_ended.emit(false)

  var player: AudioStreamPlayer = _volume_settings._preview_player
  assert_str(String(player.bus)).is_equal("SFX_UI")
  assert_object(player.stream).is_same(SfxManager.catalog.table["ui_hover"])


func test_no_preview_for_non_sfx_buses() -> void:
  assert_bool(_volume_settings.play_preview(&"Master")).is_false()
  assert_bool(_volume_settings.play_preview(&"Music")).is_false()
  assert_object(_volume_settings._preview_player.stream).is_null()


func test_preview_player_works_while_paused() -> void:
  assert_int(_volume_settings._preview_player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


#---------------------------------------------------------------------
# Helpers
#---------------------------------------------------------------------
func _remove_test_settings() -> void:
  if FileAccess.file_exists(TEST_SETTINGS_PATH):
    DirAccess.remove_absolute(TEST_SETTINGS_PATH)
