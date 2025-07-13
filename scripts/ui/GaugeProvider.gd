extends Node
class_name GaugeProvider

## ---- signals --------------------------
signal gauge_registered(provider)
signal gauge_unregistered(provider)
signal gauge_changed(current: float, max: float)
signal gauge_style_changed(style: String)

## ---- editor-exposed -------------------
@export var gauge_style := "cooldown"      # or "durability"
@export var gauge_icon  : Texture2D
@export var gauge_max   := 100.0
@export var gauge_label: String = "Gauge"  # HUD 上のラベル
@export var show_on_hud: bool = true
var gauge_current := gauge_max

## ---- life-cycle -----------------------
func _ready():
  add_to_group("gauge_providers")
  if show_on_hud:
    emit_signal("gauge_registered", self)

func _exit_tree():
  emit_signal("gauge_unregistered", self)

## ---- API ------------------------------
func set_gauge(value: float):
  gauge_current = clamp(value, 0.0, gauge_max)
  emit_signal("gauge_changed", gauge_current, gauge_max)

func init_gauge(style: String, max_value: float, _current_value: float = 0.0, _label: String = "Gauge"):
  gauge_style = style
  gauge_max = max_value
  gauge_label = _label
  call_deferred("set_gauge", _current_value)  # 初期値を設定