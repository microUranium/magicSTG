extends CanvasLayer
class_name SceneTransition
## シーン遷移時に画面全体を黒で覆うフェードレイヤー。GameFlow が子ノードとして保持する。
## ステージ内演出用の暗転（CutsceneFade）とは別物で、HUD やポーズ画面も含めて最前面を覆う。
## フェード中（暗転中を含む）は入力を握りつぶし、遷移中のボタン連打などを防ぐ。

const LAYER := 128  # CanvasLayer の最大値。PauseLayer(100) より手前に描画する

var _rect: ColorRect
var _tween: Tween
var _blocking_input := false


func _init() -> void:
  layer = LAYER
  process_mode = Node.PROCESS_MODE_ALWAYS  # ツリーのポーズ中でもフェードを進める

  _rect = ColorRect.new()
  _rect.name = "FadeRect"
  _rect.color = Color(0, 0, 0, 0)
  _rect.set_anchors_preset(Control.PRESET_FULL_RECT)
  _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _rect.visible = false
  add_child(_rect)


func _input(_event: InputEvent) -> void:
  if _blocking_input:
    get_viewport().set_input_as_handled()


func fade_out(duration: float) -> void:
  """画面を暗転させる。暗転し切るまで await できる。開始時点から入力をブロックする。"""
  _set_blocking_input(true)
  await _fade_to(1.0, duration)


func fade_in(duration: float) -> void:
  """暗転を解除する。解除し切るまで await でき、完了時に入力ブロックを解く。"""
  await _fade_to(0.0, duration)
  _set_blocking_input(false)


func is_black() -> bool:
  return is_equal_approx(_rect.color.a, 1.0)


func is_blocking_input() -> bool:
  return _blocking_input


func _fade_to(target_alpha: float, duration: float) -> void:
  if _tween and _tween.is_valid():
    _tween.kill()
    _tween = null

  if duration <= 0.0 or not is_inside_tree():
    _apply_alpha(target_alpha)
    return

  _rect.visible = true
  _tween = create_tween()
  _tween.tween_property(_rect, "color:a", target_alpha, duration)
  await _tween.finished
  _apply_alpha(target_alpha)


func _apply_alpha(alpha: float) -> void:
  _rect.color.a = alpha
  _rect.visible = alpha > 0.0


func _set_blocking_input(blocking: bool) -> void:
  _blocking_input = blocking
  _rect.mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE
