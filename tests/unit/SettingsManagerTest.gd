class_name SettingsManagerTest
extends GdUnitTestSuite

const TEST_SETTINGS_PATH := "user://test_settings_manager.cfg"

# オートロードの状態を退避・復元するための保持領域
var _orig_settings_path: String
var _orig_volumes: Dictionary


func before_test() -> void:
  _orig_settings_path = SettingsManager.settings_path
  _orig_volumes = SettingsManager._volumes.duplicate()

  SettingsManager.settings_path = TEST_SETTINGS_PATH
  _remove_test_settings()
  SettingsManager.load_settings()


func after_test() -> void:
  _remove_test_settings()
  SettingsManager.settings_path = _orig_settings_path
  SettingsManager._volumes = _orig_volumes
  SettingsManager._apply_all()
  SettingsManager._dirty = false


# ───────────────────────────────────
# Tests
# ───────────────────────────────────
func test_load_without_file_uses_default_volumes() -> void:
  for bus in SettingsManager.AUDIO_BUSES:
    assert_float(SettingsManager.get_bus_volume(bus)).is_equal(SettingsManager.DEFAULT_VOLUME)
    var idx := AudioServer.get_bus_index(bus)
    assert_int(idx).is_greater_equal(0)
    assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(0.0, 0.001)
    assert_bool(AudioServer.is_bus_mute(idx)).is_false()
  assert_bool(SettingsManager.has_unsaved_changes()).is_false()


func test_set_bus_volume_applies_to_audio_server() -> void:
  SettingsManager.set_bus_volume(&"Music", 0.5)

  var idx := AudioServer.get_bus_index(&"Music")
  assert_float(SettingsManager.get_bus_volume(&"Music")).is_equal(0.5)
  assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.5), 0.001)
  assert_bool(SettingsManager.has_unsaved_changes()).is_true()


func test_zero_volume_mutes_bus_and_restores_on_raise() -> void:
  var idx := AudioServer.get_bus_index(&"SFX")

  SettingsManager.set_bus_volume(&"SFX", 0.0)
  assert_bool(AudioServer.is_bus_mute(idx)).is_true()

  SettingsManager.set_bus_volume(&"SFX", 0.25)
  assert_bool(AudioServer.is_bus_mute(idx)).is_false()
  assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.25), 0.001)


func test_set_bus_volume_clamps_out_of_range() -> void:
  SettingsManager.set_bus_volume(&"Master", 1.5)
  assert_float(SettingsManager.get_bus_volume(&"Master")).is_equal(1.0)

  SettingsManager.set_bus_volume(&"Master", -0.5)
  assert_float(SettingsManager.get_bus_volume(&"Master")).is_equal(0.0)


func test_set_unknown_bus_is_ignored() -> void:
  SettingsManager.set_bus_volume(&"Unknown", 0.3)

  assert_bool(SettingsManager._volumes.has(&"Unknown")).is_false()
  assert_bool(SettingsManager.has_unsaved_changes()).is_false()


func test_settings_changed_emitted_only_on_change() -> void:
  var received := []
  var cb := func(section: String, key: String, value: Variant) -> void:
    received.append([section, key, value])
  SettingsManager.settings_changed.connect(cb)

  SettingsManager.set_bus_volume(&"SFX_UI", 0.4)
  SettingsManager.set_bus_volume(&"SFX_UI", 0.4)

  SettingsManager.settings_changed.disconnect(cb)
  assert_int(received.size()).is_equal(1)
  assert_array(received[0]).contains_exactly([SettingsManager.SECTION_AUDIO, "SFX_UI", 0.4])


func test_save_and_load_roundtrip_restores_volumes() -> void:
  SettingsManager.set_bus_volume(&"Master", 0.8)
  SettingsManager.set_bus_volume(&"Music", 0.3)
  SettingsManager.set_bus_volume(&"SFX", 0.0)
  SettingsManager.set_bus_volume(&"SFX_UI", 0.55)

  assert_bool(SettingsManager.save_settings()).is_true()
  assert_bool(SettingsManager.has_unsaved_changes()).is_false()

  SettingsManager.reset_to_defaults()
  SettingsManager.load_settings()

  assert_float(SettingsManager.get_bus_volume(&"Master")).is_equal_approx(0.8, 0.0001)
  assert_float(SettingsManager.get_bus_volume(&"Music")).is_equal_approx(0.3, 0.0001)
  assert_float(SettingsManager.get_bus_volume(&"SFX")).is_equal(0.0)
  assert_float(SettingsManager.get_bus_volume(&"SFX_UI")).is_equal_approx(0.55, 0.0001)
  assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX"))).is_true()
  assert_bool(SettingsManager.has_unsaved_changes()).is_false()


func test_save_if_dirty_writes_only_when_changed() -> void:
  assert_bool(SettingsManager.save_if_dirty()).is_false()
  assert_bool(FileAccess.file_exists(TEST_SETTINGS_PATH)).is_false()

  SettingsManager.set_bus_volume(&"Music", 0.7)

  assert_bool(SettingsManager.save_if_dirty()).is_true()
  assert_bool(FileAccess.file_exists(TEST_SETTINGS_PATH)).is_true()
  assert_bool(SettingsManager.save_if_dirty()).is_false()


func test_load_corrupted_file_falls_back_to_defaults() -> void:
  SettingsManager.set_bus_volume(&"Music", 0.2)
  _write_test_settings("this is [not a valid = config")

  SettingsManager.load_settings()

  assert_float(SettingsManager.get_bus_volume(&"Music")).is_equal(SettingsManager.DEFAULT_VOLUME)


func test_load_invalid_value_falls_back_to_default_for_that_bus() -> void:
  _write_test_settings('[audio]\nMaster=0.4\nMusic="loud"\nSFX=3.0\n')

  SettingsManager.load_settings()

  assert_float(SettingsManager.get_bus_volume(&"Master")).is_equal_approx(0.4, 0.0001)
  assert_float(SettingsManager.get_bus_volume(&"Music")).is_equal(SettingsManager.DEFAULT_VOLUME)
  assert_float(SettingsManager.get_bus_volume(&"SFX")).is_equal(1.0)  # 範囲外はクランプ
  assert_float(SettingsManager.get_bus_volume(&"SFX_UI")).is_equal(SettingsManager.DEFAULT_VOLUME)


func test_settings_are_separate_from_game_save() -> void:
  SettingsManager.set_bus_volume(&"Music", 0.3)

  assert_str(SettingsManager.DEFAULT_SETTINGS_PATH).is_not_equal(SaveManager.DEFAULT_SAVE_PATH)
  var save_dict := SaveManager.build_save_dict()
  assert_bool(save_dict.has(SettingsManager.SECTION_AUDIO)).is_false()


# ───────────────────────────────────
# Helpers
# ───────────────────────────────────
func _write_test_settings(text: String) -> void:
  var f := FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
  f.store_string(text)
  f.close()


func _remove_test_settings() -> void:
  if FileAccess.file_exists(TEST_SETTINGS_PATH):
    DirAccess.remove_absolute(TEST_SETTINGS_PATH)
