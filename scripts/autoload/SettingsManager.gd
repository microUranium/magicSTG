extends Node
## ゲーム設定（音量など）の保存・読み込みと反映を一元管理する。
## ゲームの進行データ（SaveManager の save_data.json）とは別ファイルに保存する。
##
## 設定は ConfigFile のセクション単位で持つ。画面サイズなどの項目を追加する場合は
## 新しいセクション（例: "display"）を追加し、load_settings / save_settings で読み書きする。
##
## セーブタイミング:
##   - 音量スライダーを離したとき（VolumeSettings）
##   - 設定画面・ポーズ画面を閉じたとき（未保存の変更がある場合のみ）
## ロードはゲーム起動時に自動で行う（このノードの _ready）。

signal settings_changed(section: String, key: String, value: Variant)

const DEFAULT_SETTINGS_PATH := "user://settings.cfg"

const SECTION_AUDIO := "audio"
## 音量設定の対象バス（default_bus_layout.tres のバス名）
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"SFX_UI"]
const DEFAULT_VOLUME := 1.0

## テストなどで保存先を差し替えられるよう変数にしている
var settings_path := DEFAULT_SETTINGS_PATH

# バス名 -> 音量（0.0〜1.0 のリニア値）
var _volumes: Dictionary = {}
var _dirty := false


func _ready() -> void:
  load_settings()


#---------------------------------------------------------------------
# Audio
#---------------------------------------------------------------------
func get_bus_volume(bus: StringName) -> float:
  return _volumes.get(bus, DEFAULT_VOLUME)


## 音量（0.0〜1.0）を設定し、即座にオーディオバスへ反映する。保存は別途行う。
func set_bus_volume(bus: StringName, volume: float) -> void:
  if bus not in AUDIO_BUSES:
    push_warning("SettingsManager: Unknown audio bus '%s'" % bus)
    return
  volume = clampf(volume, 0.0, 1.0)
  if is_equal_approx(get_bus_volume(bus), volume):
    return
  _volumes[bus] = volume
  _dirty = true
  _apply_bus_volume(bus)
  settings_changed.emit(SECTION_AUDIO, String(bus), volume)


#---------------------------------------------------------------------
# Save / Load
#---------------------------------------------------------------------
## 現在の設定を設定ファイルへ書き出す。
func save_settings() -> bool:
  var cf := ConfigFile.new()
  for bus in AUDIO_BUSES:
    cf.set_value(SECTION_AUDIO, bus, get_bus_volume(bus))

  var err := cf.save(settings_path)
  if err != OK:
    push_error("SettingsManager: Failed to save %s (error %d)" % [settings_path, err])
    return false
  _dirty = false
  return true


## 未保存の変更がある場合のみ保存する。保存した場合は true を返す。
func save_if_dirty() -> bool:
  if not _dirty:
    return false
  return save_settings()


func has_unsaved_changes() -> bool:
  return _dirty


## 設定ファイルを読み込んで反映する。無い・壊れている項目は既定値を使う。
func load_settings() -> void:
  reset_to_defaults()

  if FileAccess.file_exists(settings_path):
    var cf := ConfigFile.new()
    var err := cf.load(settings_path)
    if err == OK:
      for bus in AUDIO_BUSES:
        var v = cf.get_value(SECTION_AUDIO, bus, DEFAULT_VOLUME)
        if v is float or v is int:
          _volumes[bus] = clampf(v, 0.0, 1.0)
        else:
          push_warning("SettingsManager: Invalid volume for '%s'; fallback to default." % bus)
    else:
      push_warning("SettingsManager: Corrupted settings %s; fallback to default." % settings_path)

  _dirty = false
  _apply_all()


## 全設定を既定値に戻して反映する。保存は別途行う。
func reset_to_defaults() -> void:
  for bus in AUDIO_BUSES:
    _volumes[bus] = DEFAULT_VOLUME
  _dirty = true
  _apply_all()


#---------------------------------------------------------------------
# Private
#---------------------------------------------------------------------
func _apply_all() -> void:
  for bus in AUDIO_BUSES:
    _apply_bus_volume(bus)


func _apply_bus_volume(bus: StringName) -> void:
  var idx := AudioServer.get_bus_index(bus)
  if idx < 0:
    push_warning("SettingsManager: Audio bus '%s' not found in bus layout" % bus)
    return
  var volume := get_bus_volume(bus)
  # linear_to_db(0) は -inf になるため、0 はミュートで表現する
  AudioServer.set_bus_mute(idx, volume <= 0.0)
  if volume > 0.0:
    AudioServer.set_bus_volume_db(idx, linear_to_db(volume))
