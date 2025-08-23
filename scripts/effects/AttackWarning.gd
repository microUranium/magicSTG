# 攻撃警告線コンポーネント
extends Node2D
class_name AttackWarning

@onready var glow_line: Line2D = $GlowLine
@onready var outline_rect: Node2D = $OutlineRect  # 長方形外郭用ノード

var outline_color: Color
var outline_width: float
var outline_length: float
var rect_direction: Vector2

# 追従機能用
var owner_node: Node2D = null
var position_offset: Vector2 = Vector2.ZERO


func initialize(
  start_pos: Vector2, end_pos: Vector2, config: AttackWarningConfig, owner: Node2D = null
):
  # 相対座標の場合の設定
  if config.use_relative_position and owner:
    owner_node = owner
    position_offset = config.position_offset
    # 初期位置を設定
    global_position = owner.global_position + config.position_offset

  _setup_glow_line(start_pos, end_pos, config)
  _setup_outline_rect(start_pos, end_pos, config)
  _start_fade_in(config.warning_duration)


func _setup_glow_line(start: Vector2, end: Vector2, config: AttackWarningConfig):
  glow_line.clear_points()
  glow_line.add_point(start)
  glow_line.add_point(end)
  glow_line.width = config.glow_width
  glow_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH

  var glow_material = ShaderMaterial.new()
  glow_material.shader = preload("res://assets/shaders/warning_glow.gdshader")
  glow_material.set_shader_parameter(
    "warning_color", Vector3(config.base_color.r, config.base_color.g, config.base_color.b)
  )
  glow_material.set_shader_parameter("glow_intensity", config.glow_intensity)
  glow_material.set_shader_parameter("fade_progress", 0.0)
  glow_line.material = glow_material


func _setup_outline_rect(start: Vector2, end: Vector2, config: AttackWarningConfig):
  if config.use_relative_position and owner_node:
    start += owner_node.global_position
    end += owner_node.global_position

  # 長方形パラメータを設定
  outline_color = config.base_color
  outline_color.a = 0.0  # 初期透明
  outline_width = config.outline_width
  outline_length = start.distance_to(end)
  rect_direction = (end - start).normalized()

  # 長方形の中心位置を設定
  outline_rect.global_position = start + rect_direction * outline_length * 0.5
  outline_rect.rotation = rect_direction.angle()


func _start_fade_in(duration: float):
  var tween = create_tween()
  tween.parallel().tween_method(_update_glow_progress, 0.0, 1.0, duration)
  tween.parallel().tween_method(_update_outline_rect_alpha, 0.0, 1.0, duration)
  tween.tween_callback(queue_free)


func _update_glow_progress(progress: float):
  if glow_line.material:
    glow_line.material.set_shader_parameter("fade_progress", progress)


func _update_outline_rect_alpha(alpha: float):
  outline_color.a = alpha
  outline_rect.queue_redraw()


# 座標追従処理
func _process(_delta: float) -> void:
  if owner_node:
    global_position = owner_node.global_position + position_offset


# 長方形の外郭を描画
func _ready():
  outline_rect.draw.connect(_draw_outline_rect)


func _draw_outline_rect():
  if outline_color.a <= 0.0:
    return

  # 長方形の4つの角を計算（中心基準）
  var half_length = outline_length * 0.5
  var half_width = outline_width * 0.5

  var rect_points = PackedVector2Array()
  rect_points.append(Vector2(-half_length, -half_width))
  rect_points.append(Vector2(half_length, -half_width))
  rect_points.append(Vector2(half_length, half_width))
  rect_points.append(Vector2(-half_length, half_width))
  rect_points.append(Vector2(-half_length, -half_width))  # 閉じる

  # 長方形の輪郭を描画
  for i in range(rect_points.size() - 1):
    outline_rect.draw_line(rect_points[i], rect_points[i + 1], outline_color, 2.0)
