extends Node
class_name ButtonFeedback

## ボタンを押したときの見た目と音のフィードバックを付ける部品。
## 押すと少し縮み、離すと元より少し膨らんでからすぐ元の大きさに戻る。離したときにクリック音を鳴らす。
##
## 親の Control を「押される側（トリガー）」として扱う:
## - 親が BaseButton: button_down / pressed / button_up を監視する
## - それ以外の Control（Label＋ClickArea の疑似ボタン）: gui_input を監視し、
##   領域内で左クリックを離したときに pressed を発火する
##
## BaseButton には ButtonFeedbackInstaller（autoload）が自動で付ける。
## 拡縮させるノードや効果音を変えたい場合は attach() で明示的に付ける（自動付与はスキップされる）。

## 疑似ボタン（BaseButton 以外のトリガー）で、領域内で左クリックを離したときに発火する
signal pressed

const DEFAULT_CLICK_SFX := "ui_click"
const DEFAULT_HOVER_SFX := "ui_hover"
const CLICK_VOLUME_DB := 0.0
const HOVER_VOLUME_DB := -5.0

const PRESS_SCALE := 0.9  # 押している間の倍率
const RELEASE_SCALE := 1.08  # 離した直後に膨らむ倍率
const PRESS_DURATION := 0.05
const RELEASE_GROW_DURATION := 0.06
const RELEASE_SETTLE_DURATION := 0.1
const HOVER_DURATION := 0.15

## 拡縮させるノード。null ならトリガー（親）自身
@export var target: Control
## クリック時の効果音（SFXCatalog 名）。空なら鳴らさない
@export var click_sfx: String = DEFAULT_CLICK_SFX
## ホバー開始時の効果音。空なら鳴らさない
@export var hover_sfx: String = ""
## ホバー中の倍率。1.0 ならホバーで拡縮しない
@export var hover_scale: float = 1.0
## target の pivot_offset を中心に合わせる（見た目の位置は変わらないよう position を補正する）。
## false の場合は呼び出し側で pivot_offset を設定する
@export var center_pivot: bool = true

var _trigger: Control
var _base_scale := Vector2.ONE
var _press_factor := 1.0
var _hover_factor := 1.0
var _press_tween: Tween
var _hover_tween: Tween
var _pressing := false  # 疑似ボタン: 左クリックを押している最中か
var _clicked_this_press := false  # BaseButton: 今回の押下で pressed が発火したか


## trigger に ButtonFeedback を付けて返す。target を省略するとトリガー自身を拡縮する
static func attach(
  trigger: Control, click_sfx_name: String = DEFAULT_CLICK_SFX, scale_target: Control = null
) -> ButtonFeedback:
  var feedback := ButtonFeedback.new()
  feedback.name = "ButtonFeedback"
  feedback.click_sfx = click_sfx_name
  feedback.target = scale_target
  trigger.add_child(feedback)
  return feedback


## trigger に付いている ButtonFeedback を返す（無ければ null）
static func find_on(trigger: Node) -> ButtonFeedback:
  for child in trigger.get_children():
    if child is ButtonFeedback:
      return child
  return null


func _ready() -> void:
  _trigger = get_parent() as Control
  if not _trigger:
    push_warning("ButtonFeedback: parent must be a Control")
    return
  if not target:
    target = _trigger
  _base_scale = target.scale

  if _trigger is BaseButton:
    var button := _trigger as BaseButton
    button.button_down.connect(_play_press)
    button.button_up.connect(_on_button_up)
    button.pressed.connect(_on_button_pressed)
  else:
    _trigger.mouse_filter = Control.MOUSE_FILTER_STOP
    _trigger.gui_input.connect(_on_gui_input)

  _trigger.mouse_entered.connect(_on_mouse_entered)
  _trigger.mouse_exited.connect(_on_mouse_exited)
  # 押下中やホバー中に隠れたら（パネルを閉じた等）拡縮を残さない
  _trigger.visibility_changed.connect(_on_visibility_changed)
  target.resized.connect(_update_pivot)
  # コンテナ配下ではサイズが確定するのが後になるため遅延させる
  _update_pivot.call_deferred()


#---------------------------------------------------------------------
# Public API
#---------------------------------------------------------------------
## ホバー拡大を元に戻す（ホバー中のボタンの上にパネルを重ねたときなど、mouse_exited が来ない場合用）
func clear_hover() -> void:
  _tween_hover(1.0)


## アニメーションを止めて元の大きさに即座に戻す
func reset() -> void:
  _kill_tween(_press_tween)
  _kill_tween(_hover_tween)
  _pressing = false
  _press_factor = 1.0
  _hover_factor = 1.0
  _apply_scale()


#---------------------------------------------------------------------
# Input Handlers
#---------------------------------------------------------------------
func _on_button_pressed() -> void:
  # BaseButton は離したときに pressed → button_up の順で発火する想定だが、
  # 順序に依存しないようフラグで判定する（pressed が後なら _play_click がキャンセルを上書きする）
  _clicked_this_press = true
  _play_click()


func _on_button_up() -> void:
  if not _clicked_this_press:
    _play_cancel()  # ボタンの外で離した
  _clicked_this_press = false


func _on_gui_input(event: InputEvent) -> void:
  var mouse_button := event as InputEventMouseButton
  if not mouse_button or mouse_button.button_index != MOUSE_BUTTON_LEFT:
    return
  _trigger.accept_event()

  if mouse_button.pressed:
    _pressing = true
    _play_press()
  elif _pressing:
    _pressing = false
    if Rect2(Vector2.ZERO, _trigger.size).has_point(mouse_button.position):
      _play_click()
      pressed.emit()
    else:
      _play_cancel()


func _on_mouse_entered() -> void:
  if _trigger is BaseButton and (_trigger as BaseButton).disabled:
    return
  _tween_hover(hover_scale)
  _play_sfx(hover_sfx, HOVER_VOLUME_DB)


func _on_mouse_exited() -> void:
  _tween_hover(1.0)


func _on_visibility_changed() -> void:
  if not _trigger.is_visible_in_tree():
    reset()


#---------------------------------------------------------------------
# Animation
#---------------------------------------------------------------------
func _play_press() -> void:
  _clicked_this_press = false
  var tween := _restart_press_tween()
  tween.tween_method(_set_press_factor, _press_factor, PRESS_SCALE, PRESS_DURATION).set_trans(
    Tween.TRANS_QUAD
  )


func _play_click() -> void:
  var tween := _restart_press_tween()
  (
    tween
    . tween_method(_set_press_factor, _press_factor, RELEASE_SCALE, RELEASE_GROW_DURATION)
    . set_trans(Tween.TRANS_QUAD)
  )
  tween.tween_method(_set_press_factor, RELEASE_SCALE, 1.0, RELEASE_SETTLE_DURATION).set_trans(
    Tween.TRANS_SINE
  )
  _play_sfx(click_sfx, CLICK_VOLUME_DB)


func _play_cancel() -> void:
  var tween := _restart_press_tween()
  tween.tween_method(_set_press_factor, _press_factor, 1.0, RELEASE_SETTLE_DURATION).set_trans(
    Tween.TRANS_SINE
  )


func _tween_hover(target_factor: float) -> void:
  if is_equal_approx(_hover_factor, target_factor):
    return
  _kill_tween(_hover_tween)
  _hover_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
  _hover_tween.tween_method(_set_hover_factor, _hover_factor, target_factor, HOVER_DURATION)


func _restart_press_tween() -> Tween:
  _kill_tween(_press_tween)
  _press_tween = create_tween().set_ease(Tween.EASE_OUT)
  return _press_tween


func _set_press_factor(value: float) -> void:
  _press_factor = value
  _apply_scale()


func _set_hover_factor(value: float) -> void:
  _hover_factor = value
  _apply_scale()


func _apply_scale() -> void:
  if is_instance_valid(target):
    target.scale = _base_scale * _press_factor * _hover_factor


func _kill_tween(tween: Tween) -> void:
  if tween and tween.is_valid():
    tween.kill()


## pivot_offset を target の中心へ移す。scale が 1 以外のノードは pivot を動かすと
## 見た目の位置がずれるため、その分を position で打ち消す
func _update_pivot() -> void:
  if not center_pivot or not is_instance_valid(target):
    return
  var new_pivot := target.size / 2.0
  var delta := new_pivot - target.pivot_offset
  if delta.is_zero_approx():
    return
  # Control の描画位置: position + pivot + R*S*(x - pivot)
  # pivot を delta 動かしても見た目が変わらないよう position に (R*S - I) * delta を足す
  var basis := Transform2D(target.rotation, target.scale, 0.0, Vector2.ZERO)
  target.position += basis * delta - delta
  target.pivot_offset = new_pivot


func _play_sfx(sfx_name: String, volume_db: float) -> void:
  if sfx_name.is_empty():
    return
  StageSignals.sfx_play_requested.emit(sfx_name, Vector2.INF, volume_db, 1.0)
