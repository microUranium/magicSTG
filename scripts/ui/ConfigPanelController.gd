extends Control
class_name ConfigPanelController

## 設定画面（タイトル画面にオーバーレイ表示する）の制御
## 設定項目は Content/Sections 配下にセクション（見出し＋設定部品）単位で並べる。
## 画面サイズなどの項目を追加する場合は Sections に新しいセクションを追加する。

#---------------------------------------------------------------------
# Signals
#---------------------------------------------------------------------
signal opened
signal closed

#---------------------------------------------------------------------
# Node References
#---------------------------------------------------------------------
@onready var _volume_settings: VolumeSettings = $Content/Sections/Sound/VolumeSettings
@onready var _back_button_area: Control = $Back/ClickArea
@onready var _back_label: Label = $Back/Label

#---------------------------------------------------------------------
# Constants
#---------------------------------------------------------------------
const HOVER_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const HOVER_DURATION := 0.15

var _back_hover_tween: Tween = null


#---------------------------------------------------------------------
# Lifecycle
#---------------------------------------------------------------------
func _ready() -> void:
  visible = false
  _setup_button_detection()


func _unhandled_input(event: InputEvent) -> void:
  if not visible:
    return
  if event is InputEventKey:
    if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
      close()
      get_viewport().set_input_as_handled()


#---------------------------------------------------------------------
# Public API
#---------------------------------------------------------------------
func open() -> void:
  """設定画面を表示"""
  if visible:
    return
  _volume_settings.refresh()
  visible = true
  opened.emit()


func close() -> void:
  """設定画面を閉じる（未保存の変更があれば保存する）"""
  if not visible:
    return
  SettingsManager.save_if_dirty()
  visible = false
  # 閉じた時点のホバー拡大が次回表示時に残らないよう戻す
  if _back_hover_tween and _back_hover_tween.is_valid():
    _back_hover_tween.kill()
  _back_label.scale = NORMAL_SCALE
  closed.emit()


func is_open() -> bool:
  return visible


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------
func _setup_button_detection() -> void:
  """「もどる」ボタンのクリック検出とホバー検出をセットアップ"""
  if not _back_button_area:
    push_warning("ConfigPanelController: Back button area not found")
    return

  _back_button_area.mouse_filter = Control.MOUSE_FILTER_STOP
  _back_button_area.gui_input.connect(_on_back_area_input)
  _back_button_area.mouse_entered.connect(_on_back_hover_start)
  _back_button_area.mouse_exited.connect(_on_back_hover_end)


func _animate_back_label_scale(target_scale: Vector2) -> void:
  """「もどる」Labelのスケールをアニメーション"""
  if _back_hover_tween and _back_hover_tween.is_valid():
    _back_hover_tween.kill()

  _back_hover_tween = create_tween()
  _back_hover_tween.set_ease(Tween.EASE_OUT)
  _back_hover_tween.set_trans(Tween.TRANS_BACK)
  _back_hover_tween.tween_property(_back_label, "scale", target_scale, HOVER_DURATION)


#---------------------------------------------------------------------
# Button Event Handlers
#---------------------------------------------------------------------
func _on_back_area_input(event: InputEvent) -> void:
  """「もどる」ボタンのクリック検出"""
  if event is InputEventMouseButton:
    if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
      _back_button_area.accept_event()
      _play_click_sfx()
      close()


func _on_back_hover_start() -> void:
  _animate_back_label_scale(HOVER_SCALE)
  _play_hover_sfx()


func _on_back_hover_end() -> void:
  _animate_back_label_scale(NORMAL_SCALE)


#---------------------------------------------------------------------
# Sound Effects
#---------------------------------------------------------------------
func _play_hover_sfx() -> void:
  """ホバー時のSFX再生"""
  StageSignals.emit_signal("sfx_play_requested", "ui_hover", Vector2.INF, -5.0, 1.0)


func _play_click_sfx() -> void:
  """クリック時のSFX再生"""
  StageSignals.emit_signal("sfx_play_requested", "ui_click", Vector2.INF, 0.0, 1.0)
