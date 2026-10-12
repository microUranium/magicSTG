extends CanvasLayer
class_name ScreenFade
## 画面全体を黒で覆う暗転レイヤー。
## HUD(layer 10) より背面に置くため、暗転中も HUD は見えたままになる。

@export var fade_rect_path: NodePath = ^"FadeRect"

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
  _rect = get_node_or_null(fade_rect_path) as ColorRect
  if _rect == null:
    push_warning("ScreenFade: FadeRect not found at path: %s" % fade_rect_path)
  else:
    _apply_alpha(0.0)

  StageSignals.request_screen_fade.connect(fade)


func fade(to_black: bool, duration: float) -> void:
  """暗転（to_black=true）／暗転解除（false）。duration<=0 なら即時反映。"""
  if _rect == null:
    return

  if _tween and _tween.is_valid():
    _tween.kill()
    _tween = null

  var target_alpha := 1.0 if to_black else 0.0
  if duration <= 0.0:
    _apply_alpha(target_alpha)
    return

  _rect.visible = true
  _tween = create_tween()
  _tween.tween_property(_rect, "color:a", target_alpha, duration)
  _tween.tween_callback(_apply_alpha.bind(target_alpha))


func is_black() -> bool:
  return _rect != null and is_equal_approx(_rect.color.a, 1.0)


func _apply_alpha(alpha: float) -> void:
  if _rect == null:
    return
  _rect.color.a = alpha
  _rect.visible = alpha > 0.0
