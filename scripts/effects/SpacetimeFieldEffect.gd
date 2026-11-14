extends CanvasLayer

## 時界の加護の背景演出。背景（ParallaxBackground、layer -100）のすぐ上に重ね、背景の色だけを反転する。
##
## 時間の流れ:
##   発動の瞬間  : 画面全体の背景を反転
##   〜FADE_OUT_SEC: 結界の外側だけ徐々に元の色に戻る（内側は反転のまま、自機についていく）
##   終了時      : 結界の内側を一瞬白く光らせ（FLASH_UP_SEC + FLASH_DOWN_SEC）、内側も元の色に戻して（RESTORE_SEC）消える
## アニメーションは Tween で動かす（シェーダーの TIME はポーズ中も進むため使わない）。

const SHADER := preload("res://assets/shaders/spacetime_field.gdshader")
const LAYER := -99  # 背景（ParallaxBackground の既定 -100）のすぐ上、ゲーム画面（0）より下
const FADE_OUT_SEC := 0.5
const FLASH_UP_SEC := 0.05
const FLASH_DOWN_SEC := 0.1
const RESTORE_SEC := 0.3

var _rect: ColorRect
var _material: ShaderMaterial
var _fade_tween: Tween = null


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


func finish() -> void:
  """終了：内側を一瞬光らせ、内側も元の色に戻して消える"""
  if _fade_tween and _fade_tween.is_valid():
    _fade_tween.kill()  # 発動時の演出が終わる前に終了した場合
  _set_param(0.0, "invert_outside")
  var tween := create_tween()
  tween.tween_method(_set_param.bind("flash"), 0.0, 1.0, FLASH_UP_SEC)
  tween.tween_method(_set_param.bind("flash"), 1.0, 0.0, FLASH_DOWN_SEC)
  tween.tween_method(_set_param.bind("invert_inside"), 1.0, 0.0, RESTORE_SEC)
  tween.tween_callback(queue_free)


func _set_param(value: float, param: String) -> void:
  _material.set_shader_parameter(param, value)
