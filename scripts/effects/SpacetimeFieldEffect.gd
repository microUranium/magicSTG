extends CanvasLayer

## 時界の加護の背景演出。背景（ParallaxBackground、layer -100）のすぐ上に重ね、背景の色だけを反転する。
##
## 時間の流れ:
##   発動の瞬間  : 画面全体の背景を反転
##   〜FADE_OUT_SEC: 結界の外側だけ徐々に元の色に戻る（内側は反転のまま、自機についていく）
##   終了の少し前: 結界の内側の反転が点滅する（set_warning_elapsed()。加護本体が残り時間から呼ぶ）
##   終了時      : 結界の内側を一瞬白く光らせ（FLASH_UP_SEC + FLASH_DOWN_SEC）、
##                 同時に結界が急激に縮んで（SHRINK_SEC）消える
## アニメーションは Tween か、加護本体のタイマーから計算した値で動かす
## （シェーダーの TIME はポーズ中も進むため使わない）。

const SHADER := preload("res://assets/shaders/spacetime_field.gdshader")
const LAYER := -99  # 背景（ParallaxBackground の既定 -100）のすぐ上、ゲーム画面（0）より下
const FADE_OUT_SEC := 0.5
const FLASH_UP_SEC := 0.05
const FLASH_DOWN_SEC := 0.1
const SHRINK_SEC := 0.25  # 終了時に結界が縮みきるまでの時間
const BLINK_PERIOD_SEC := 0.5  # 予告の点滅の 1 周期（暗くなる → 点く）
const BLINK_FADE_RATIO := 0.7  # 1 周期のうち、余韻を残して暗くなっていく割合（残りで点き直す）
const BLINK_OFF_INVERT := 0.15  # 点滅で一番暗いときの内側の反転の強さ（余韻として少し残す）

var _rect: ColorRect
var _material: ShaderMaterial
var _fade_tween: Tween = null
var _radius_px: float = 200.0


func _init() -> void:
  layer = LAYER
  _material = ShaderMaterial.new()
  _material.shader = SHADER
  _rect = ColorRect.new()
  _rect.name = "InvertRect"
  _rect.material = _material
  _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _rect.set_anchors_preset(Control.PRESET_FULL_RECT)
  add_child(_rect)


func get_field_material() -> ShaderMaterial:
  return _material


func start(radius_px: float) -> void:
  """発動：全体を反転し、外側だけ徐々に元に戻す"""
  _radius_px = radius_px
  _material.set_shader_parameter("radius_px", radius_px)
  _material.set_shader_parameter("invert_outside", 1.0)
  _material.set_shader_parameter("invert_inside", 1.0)
  _material.set_shader_parameter("flash", 0.0)
  _fade_tween = create_tween()
  _fade_tween.tween_method(_set_param.bind("invert_outside"), 1.0, 0.0, FADE_OUT_SEC)


func set_center(screen_pos: Vector2, view_size: Vector2) -> void:
  """結界の中心（自機の画面上の位置）を更新する"""
  if view_size.x <= 0.0 or view_size.y <= 0.0:
    return
  _material.set_shader_parameter("view_size", view_size)
  _material.set_shader_parameter("center_uv", screen_pos / view_size)


func set_warning_elapsed(elapsed: float) -> void:
  """終了前の予告点滅。elapsed は予告が始まってからの経過秒。"""
  _set_param(blink_value(elapsed), "invert_inside")


static func blink_value(elapsed: float) -> float:
  """予告点滅の内側の反転の強さ。1 周期（BLINK_PERIOD_SEC）の前半 BLINK_FADE_RATIO で
  点いた状態から余韻を残して暗くなり、残りでなめらかに点き直す。
  どちらも smoothstep でつなぐので値が飛ばず、予告の始まり（elapsed = 0）は点いた状態から。"""
  var phase := fmod(maxf(elapsed, 0.0), BLINK_PERIOD_SEC) / BLINK_PERIOD_SEC
  if phase < BLINK_FADE_RATIO:
    var t := smoothstep(0.0, 1.0, phase / BLINK_FADE_RATIO)
    return lerpf(1.0, BLINK_OFF_INVERT, t)
  var t := smoothstep(0.0, 1.0, (phase - BLINK_FADE_RATIO) / (1.0 - BLINK_FADE_RATIO))
  return lerpf(BLINK_OFF_INVERT, 1.0, t)


func finish() -> void:
  """終了：内側を一瞬光らせ、同時に結界を急激に縮めて消える"""
  if _fade_tween and _fade_tween.is_valid():
    _fade_tween.kill()  # 発動時の演出が終わる前に終了した場合
  _set_param(0.0, "invert_outside")
  _set_param(1.0, "invert_inside")  # 点滅で消えている途中でも、縮む結界が見えるように戻す
  var flash_tween := create_tween()
  flash_tween.tween_method(_set_param.bind("flash"), 0.0, 1.0, FLASH_UP_SEC)
  flash_tween.tween_method(_set_param.bind("flash"), 1.0, 0.0, FLASH_DOWN_SEC)
  var shrink_tween := create_tween()
  (
    shrink_tween
    . tween_method(_set_param.bind("radius_px"), _radius_px, 0.0, SHRINK_SEC)
    . set_trans(Tween.TRANS_CUBIC)
    . set_ease(Tween.EASE_IN)
  )
  shrink_tween.tween_callback(queue_free)


func _set_param(value: float, param: String) -> void:
  _material.set_shader_parameter(param, value)
