extends Control
class_name PausePanelController

## ポーズパネルの制御を管理
## ESCキー入力の監視、パネルの表示/非表示、ボタンイベントのハンドリングを行う

#---------------------------------------------------------------------
# Signals
#---------------------------------------------------------------------
signal pause_requested
signal resume_requested
signal quit_requested

#---------------------------------------------------------------------
# Node References
#---------------------------------------------------------------------
@onready var _dark_overlay: ColorRect = $DarkOverlay
@onready var _back_button_area: Control = $VBoxContainer/Back/ClickArea
@onready var _quit_button_area: Control = $VBoxContainer/Escape/ClickArea
@onready var _back_label: Label = $VBoxContainer/Back/Label
@onready var _quit_label: Label = $VBoxContainer/Escape/Label
@onready var _panel_container: Control = self

#---------------------------------------------------------------------
# State
#---------------------------------------------------------------------
var _is_paused: bool = false
var _can_pause: bool = false  # ステージ実行中のみポーズ可能
var _quit_button_confirmed: bool = false  # 「あきらめる」ボタンの確認状態
var _has_been_shown: bool = false  # パネルが一度でも表示されたか

# Tween管理
var _back_hover_tween: Tween = null
var _quit_hover_tween: Tween = null

#---------------------------------------------------------------------
# Constants
#---------------------------------------------------------------------
const HOVER_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const HOVER_DURATION := 0.15

# Quit Button
const QUIT_TEXT_NORMAL := "あきらめる"
const QUIT_TEXT_CONFIRM := "あきらめる？"
const QUIT_COLOR_NORMAL := Color(0.968132, 0.25534, 0.461148, 1.0)
const QUIT_COLOR_CONFIRM := Color(1.0, 0.0, 0.0, 1.0)


#---------------------------------------------------------------------
# Lifecycle
#---------------------------------------------------------------------
func _ready() -> void:
  # ポーズ中も動作するように設定
  process_mode = Node.PROCESS_MODE_ALWAYS

  # 初期状態は非表示
  hide_panel()

  # ボタン検出のセットアップ
  _setup_button_detection()


func _unhandled_input(event: InputEvent) -> void:
  # ESCキー検出
  if event is InputEventKey:
    if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
      if _can_pause:
        toggle_pause()
        get_viewport().set_input_as_handled()


#---------------------------------------------------------------------
# Public API
#---------------------------------------------------------------------
func enable_pause() -> void:
  """ステージ開始時に呼ばれる - ポーズを有効化"""
  _can_pause = true
  print_debug("PausePanelController: Pause enabled")


func disable_pause() -> void:
  """ステージ終了時に呼ばれる - ポーズを無効化"""
  _can_pause = false

  # 現在ポーズ中の場合は強制的に解除
  if _is_paused:
    _force_unpause()

  print_debug("PausePanelController: Pause disabled")


func toggle_pause() -> void:
  """ポーズ状態を切り替え"""
  if not _can_pause:
    return

  if _is_paused:
    resume_requested.emit()
  else:
    pause_requested.emit()


func show_panel() -> void:
  """パネルを表示"""
  _panel_container.visible = true
  _is_paused = true
  _has_been_shown = true  # 表示フラグを立てる

  # 暗転オーバーレイを表示
  if _dark_overlay:
    _dark_overlay.visible = true

  # ポーズ開始SFX再生
  _play_pause_open_sfx()

  print_debug("PausePanelController: Panel shown")


func hide_panel() -> void:
  """パネルを非表示"""
  _panel_container.visible = false
  _is_paused = false

  # 暗転オーバーレイを非表示
  if _dark_overlay:
    _dark_overlay.visible = false

  # 確認状態をリセット
  if _quit_button_confirmed:
    _quit_button_confirmed = false
    _update_quit_button_state()

  # ポーズ解除SFX再生（パネルが実際に表示されていた場合のみ）
  if _has_been_shown:
    _play_pause_close_sfx()

  print_debug("PausePanelController: Panel hidden")


func is_paused() -> bool:
  """現在のポーズ状態を取得"""
  return _is_paused


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------
func _setup_button_detection() -> void:
  """ボタンのクリック検出とホバー検出をセットアップ"""
  if not _back_button_area or not _quit_button_area:
    push_warning("PausePanelController: Button areas not found")
    return

  # マウスフィルターを設定して入力を受け取る
  _back_button_area.mouse_filter = Control.MOUSE_FILTER_STOP
  _quit_button_area.mouse_filter = Control.MOUSE_FILTER_STOP

  # gui_input シグナルで検出
  _back_button_area.gui_input.connect(_on_back_area_input)
  _quit_button_area.gui_input.connect(_on_quit_area_input)

  # ホバー検出
  _back_button_area.mouse_entered.connect(
    _on_button_hover_start.bind(_back_label, _back_hover_tween)
  )
  _back_button_area.mouse_exited.connect(_on_button_hover_end.bind(_back_label, _back_hover_tween))
  _quit_button_area.mouse_entered.connect(_on_quit_button_hover_start)
  _quit_button_area.mouse_exited.connect(_on_quit_button_hover_end)


func _force_unpause() -> void:
  """強制的にポーズを解除（内部用）"""
  hide_panel()
  _is_paused = false
  print_debug("PausePanelController: Force unpause")


func _update_quit_button_state() -> void:
  """「あきらめる」ボタンの表示状態を更新"""
  if not _quit_label:
    return

  if _quit_button_confirmed:
    # 確認状態: 赤色、テキスト変更
    _quit_label.text = QUIT_TEXT_CONFIRM
    _quit_label.add_theme_color_override("font_color", QUIT_COLOR_CONFIRM)
  else:
    # 通常状態: 元の色、テキスト戻す
    _quit_label.text = QUIT_TEXT_NORMAL
    _quit_label.add_theme_color_override("font_color", QUIT_COLOR_NORMAL)


#---------------------------------------------------------------------
# Button Event Handlers
#---------------------------------------------------------------------
func _on_back_area_input(event: InputEvent) -> void:
  """「もどる」ボタンのクリック検出"""
  if event is InputEventMouseButton:
    if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
      _on_back_clicked()


func _on_quit_area_input(event: InputEvent) -> void:
  """「あきらめる」ボタンのクリック検出"""
  if event is InputEventMouseButton:
    if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
      _on_quit_clicked()


func _on_back_clicked() -> void:
  """「もどる」ボタンがクリックされた"""
  _play_click_sfx()
  print_debug("PausePanelController: Back button clicked")
  resume_requested.emit()


func _on_quit_clicked() -> void:
  """「あきらめる」ボタンがクリックされた"""
  if not _quit_button_confirmed:
    # 初回クリック: 確認状態に移行
    _quit_button_confirmed = true
    _update_quit_button_state()
    _play_click_sfx()
    print_debug("PausePanelController: Quit button confirmation requested")
  else:
    # 2回目クリック: 退出実行
    _play_click_sfx()
    print_debug("PausePanelController: Quit button confirmed")
    quit_requested.emit()


#---------------------------------------------------------------------
# Hover Event Handlers
#---------------------------------------------------------------------
func _on_button_hover_start(label: Label, tween_ref: Tween) -> void:
  """ボタンにホバー開始（共通処理）"""
  _animate_label_scale(label, HOVER_SCALE, tween_ref)
  _play_hover_sfx()


func _on_button_hover_end(label: Label, tween_ref: Tween) -> void:
  """ボタンからホバー解除（共通処理）"""
  _animate_label_scale(label, NORMAL_SCALE, tween_ref)


func _on_quit_button_hover_start() -> void:
  """「あきらめる」ボタンにホバー開始"""
  _animate_label_scale(_quit_label, HOVER_SCALE, _quit_hover_tween)
  _play_hover_sfx()


func _on_quit_button_hover_end() -> void:
  """「あきらめる」ボタンからホバー解除"""
  _animate_label_scale(_quit_label, NORMAL_SCALE, _quit_hover_tween)

  # 確認状態の場合はリセット
  if _quit_button_confirmed:
    _quit_button_confirmed = false
    _update_quit_button_state()
    print_debug("PausePanelController: Quit button confirmation cancelled")


func _animate_label_scale(label: Label, target_scale: Vector2, tween_ref: Tween) -> void:
  """Labelのスケールをアニメーション"""
  if not label:
    return

  # 既存のTweenをキャンセル
  if tween_ref and tween_ref.is_valid():
    tween_ref.kill()

  # 新しいTweenを作成
  tween_ref = create_tween()
  tween_ref.set_ease(Tween.EASE_OUT)
  tween_ref.set_trans(Tween.TRANS_BACK)
  tween_ref.tween_property(label, "scale", target_scale, HOVER_DURATION)


#---------------------------------------------------------------------
# Sound Effects
#---------------------------------------------------------------------
func _play_pause_open_sfx() -> void:
  """ポーズ開始時のSFX再生"""
  StageSignals.emit_signal("sfx_play_requested", "pause_open", Vector2.INF, 0.0, 1.0)


func _play_pause_close_sfx() -> void:
  """ポーズ解除時のSFX再生"""
  StageSignals.emit_signal("sfx_play_requested", "pause_close", Vector2.INF, 0.0, 1.0)


func _play_hover_sfx() -> void:
  """ホバー時のSFX再生"""
  StageSignals.emit_signal("sfx_play_requested", "ui_hover", Vector2.INF, -5.0, 1.0)


func _play_click_sfx() -> void:
  """クリック時のSFX再生"""
  StageSignals.emit_signal("sfx_play_requested", "ui_click", Vector2.INF, 0.0, 1.0)
