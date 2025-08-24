extends Node2D
class_name HitJudgeContainer

@onready var hit_judge_point: Sprite2D = $HitJudgePoint
@onready var hit_judge_circle: Sprite2D = $HitJudgeCircle

@export var fade_time := 0.25  # フェード秒数
@export var circle_alpha_home := 0.5  # 通常時のアルファ
@export var circle_scale_home := Vector2(1.5, 1.5)  # 通常時のスケール
@export var circle_scale_fadeout := Vector2(2.0, 2.0)  # フェードアウト時のスケール
@export var circle_rotate_speed := 30.0  # 1 秒あたりの回転角度


func _ready() -> void:
  TargetService.connect("player_registered", Callable(self, "_setup"))
  _hide_hit_judge_sprite()


func _setup(player: Node2D) -> void:
  player.connect("sneak_state_changed", Callable(self, "_on_player_sneak_state_changed"))


func _on_player_sneak_state_changed(is_sneaking: bool) -> void:
  if is_sneaking:
    _visible_hit_judge_sprite()
  else:
    _hide_hit_judge_sprite()


func _visible_hit_judge_sprite() -> void:
  hit_judge_point.visible = true
  hit_judge_circle.rotation = 0.0

  var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tw.parallel().tween_property(hit_judge_circle, "modulate:a", circle_alpha_home, fade_time)
  tw.parallel().tween_property(hit_judge_circle, "scale", circle_scale_home, fade_time)
  tw.parallel().tween_property(hit_judge_circle, "rotation", PI, fade_time)
  await tw.finished


func _hide_hit_judge_sprite() -> void:
  hit_judge_point.visible = false

  var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tw.parallel().tween_property(hit_judge_circle, "modulate:a", 0.0, fade_time)
  tw.parallel().tween_property(hit_judge_circle, "scale", circle_scale_fadeout, fade_time)
  tw.parallel().tween_property(
    hit_judge_circle, "rotation", hit_judge_circle.rotation - PI, fade_time
  )
  await tw.finished


func _process(delta: float) -> void:
  if hit_judge_circle.modulate.a > 0.0:
    hit_judge_circle.rotation += deg_to_rad(circle_rotate_speed) * delta
    hit_judge_circle.rotation = fmod(hit_judge_circle.rotation, TAU)
