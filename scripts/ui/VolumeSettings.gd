extends VBoxContainer
class_name VolumeSettings

## サウンドバスごとの音量スライダー一覧（設定画面・ポーズ画面で共用）
## 子の各行はノード名をバス名（default_bus_layout.tres）とし、Slider と Value を持つ。
## スライダー操作は即座に SettingsManager へ反映し、スライダーを離したときに保存する。
## 効果音系のバスはスライダーを離したときに試聴音を鳴らす。

#---------------------------------------------------------------------
# Constants
#---------------------------------------------------------------------
## バス名 -> 試聴に使う SFX カタログ名
const PREVIEW_SFX := {&"SFX": "hit_enemy", &"SFX_UI": "ui_hover"}

#---------------------------------------------------------------------
# State
#---------------------------------------------------------------------
var _sliders: Dictionary = {}  # バス名 -> HSlider
var _value_labels: Dictionary = {}  # バス名 -> Label
var _preview_player: AudioStreamPlayer


#---------------------------------------------------------------------
# Lifecycle
#---------------------------------------------------------------------
func _ready() -> void:
  _preview_player = AudioStreamPlayer.new()
  _preview_player.name = "PreviewPlayer"
  # ポーズ中（ポーズ画面）でも試聴できるようにする
  _preview_player.process_mode = Node.PROCESS_MODE_ALWAYS
  add_child(_preview_player)

  for row in get_children():
    if not row.has_node("Slider"):
      continue
    var bus := StringName(row.name)
    var slider: HSlider = row.get_node("Slider")
    _sliders[bus] = slider
    _value_labels[bus] = row.get_node_or_null("Value")
    slider.value_changed.connect(_on_slider_value_changed.bind(bus))
    slider.drag_ended.connect(_on_slider_drag_ended.bind(bus))

  refresh()


#---------------------------------------------------------------------
# Public API
#---------------------------------------------------------------------
func refresh() -> void:
  """SettingsManager の現在値をスライダーへ反映"""
  for bus in _sliders:
    var slider: HSlider = _sliders[bus]
    slider.set_value_no_signal(SettingsManager.get_bus_volume(bus) * slider.max_value)
    _update_value_label(bus)


func play_preview(bus: StringName) -> bool:
  """指定バスで試聴音を鳴らす。試聴対象外のバスなら false"""
  var sfx_name: String = PREVIEW_SFX.get(bus, "")
  if sfx_name.is_empty():
    return false
  var stream: AudioStream = SfxManager.catalog.table.get(sfx_name)
  if stream == null:
    push_warning("VolumeSettings: Preview SFX not found in catalog: %s" % sfx_name)
    return false

  _preview_player.stop()
  _preview_player.bus = bus
  _preview_player.stream = stream
  _preview_player.play()
  return true


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------
func _update_value_label(bus: StringName) -> void:
  var label: Label = _value_labels.get(bus)
  if label:
    label.text = "%d" % roundi(_sliders[bus].value)


#---------------------------------------------------------------------
# Slider Event Handlers
#---------------------------------------------------------------------
func _on_slider_value_changed(value: float, bus: StringName) -> void:
  SettingsManager.set_bus_volume(bus, value / _sliders[bus].max_value)
  _update_value_label(bus)


func _on_slider_drag_ended(_value_changed: bool, bus: StringName) -> void:
  SettingsManager.save_if_dirty()
  play_preview(bus)
