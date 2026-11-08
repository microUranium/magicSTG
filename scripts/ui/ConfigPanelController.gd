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
const HOVER_SCALE := 1.1

var _back_feedback: ButtonFeedback = null


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
  visible = false  # 非表示になると ButtonFeedback がホバー拡大・押下アニメーションを戻す
  closed.emit()


func is_open() -> bool:
  return visible


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------
func _setup_button_detection() -> void:
  """「もどる」ボタンにクリック検出・ホバー拡大・押下アニメーション・効果音をセットアップ"""
  if not _back_button_area:
    push_warning("ConfigPanelController: Back button area not found")
    return

  _back_feedback = ButtonFeedback.attach(
    _back_button_area, ButtonFeedback.DEFAULT_CLICK_SFX, _back_label
  )
  _back_feedback.hover_scale = HOVER_SCALE
  _back_feedback.hover_sfx = ButtonFeedback.DEFAULT_HOVER_SFX
  _back_feedback.pressed.connect(close)
