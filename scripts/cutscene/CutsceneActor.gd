extends Node2D
class_name CutsceneActor
## 演出専用のキャラクター。当たり判定・HP・攻撃を持たず、移動と退場だけを行う。

@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"
@export var default_animation: StringName = &"default"

var _move_tween: Tween = null


func _ready() -> void:
  var sprite := get_node_or_null(animated_sprite_path) as AnimatedSprite2D
  if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(default_animation):
    sprite.play(default_animation)


func warp_to(target_position: Vector2) -> void:
  """即座に指定座標へ移動する。"""
  _kill_move_tween()
  global_position = target_position


func move_to(target_position: Vector2, duration: float) -> Tween:
  """指定座標へ duration 秒かけて移動する。duration<=0 なら即時ワープ。"""
  _kill_move_tween()
  if duration <= 0.0:
    global_position = target_position
    return null

  _move_tween = create_tween()
  _move_tween.tween_property(self, "global_position", target_position, duration)
  return _move_tween


func exit_to(target_position: Vector2, duration: float) -> void:
  """画面外へ移動してから自身を削除する（撃破扱いの退場）。"""
  var tween := move_to(target_position, duration)
  if tween == null:
    queue_free()
    return
  tween.tween_callback(queue_free)


func _kill_move_tween() -> void:
  if _move_tween and _move_tween.is_valid():
    _move_tween.kill()
  _move_tween = null
