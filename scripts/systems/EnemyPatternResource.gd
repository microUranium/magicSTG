@tool
extends Resource
class_name EnemyPatternResource

enum MovementType { MOVE_TO_POSITION, MOVE_DIRECTION, STAY_IN_PLACE }  # 特定座標への移動（既存）  # 方向とスピードで移動  # その場で停止

enum DirectionType { FIXED_ANGLE, TO_PLAYER, AWAY_FROM_PLAYER, CONTINUE_PREVIOUS }  # 固定角度  # プレイヤー方向  # プレイヤーから離れる方向  # 前のパターンの移動方向を継続

@export var movement_type: MovementType = MovementType.MOVE_TO_POSITION
@export var move_to: Vector2 = Vector2.ZERO
@export var move_time: float = 1.0

@export_group("Directional Movement")
@export var direction_type: DirectionType = DirectionType.FIXED_ANGLE
@export var move_angle: float = 0.0  # 度数で指定（0=右、90=下、180=左、270=上）
@export var move_speed: float = 100.0
@export var use_movement_bounds: bool = false  # 移動範囲制限を使用するか
@export var movement_bounds: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)  # 移動可能範囲（PlayArea基準の割合 0.0-1.0）

@export_group("Core Control")
@export var core_to_enable: String = ""  # AttackCoreSlot 内子ノード名
@export var core_duration: float = 3.0

@export_group("Animation Control")
@export var change_animation: bool = false
@export var animation_name: String = ""  # 変更するアニメーション名
@export var restore_animation: bool = true  # パターン終了時に元のアニメーションに戻すか

@export_group("Dialogue")
@export var dialogue_path: String = ""  # stage_data.json の会話パス（新方式）

var _original_animation: String = ""


func start(enemy: Node2D, _ai: Node, finished_cb: Callable):
  # 0. handle animation change if needed
  _handle_animation_change(enemy)

  # 1. optional dialogue (新方式優先、レガシー方式フォールバック)
  if not dialogue_path.is_empty():
    _handle_json_dialogue(dialogue_path, func(): _on_pattern_complete(enemy, finished_cb))
    return

  # 2. movement based on type
  var wrapped_callback = func(): _on_pattern_complete(enemy, finished_cb)
  match movement_type:
    MovementType.MOVE_TO_POSITION:
      return _execute_move_to_position(enemy, _ai, wrapped_callback)
    MovementType.MOVE_DIRECTION:
      return _execute_directional_movement(enemy, _ai, wrapped_callback)
    MovementType.STAY_IN_PLACE:
      return _execute_stay_in_place(enemy, wrapped_callback)


func _execute_move_to_position(enemy: Node2D, ai: Node, finished_cb: Callable):
  var tw = enemy.create_tween()
  tw.tween_property(enemy, "global_position", move_to, move_time)
  print_debug("EnemyPatternResource: move_to ", move_to, " time ", move_time)

  # Store movement direction for future use
  if ai and ai.has_method("set_last_movement_direction"):
    var direction = (move_to - enemy.global_position).normalized()
    ai.set_last_movement_direction(direction)

  if core_to_enable.is_empty():
    tw.tween_callback(finished_cb)
  else:
    tw.tween_callback(func(): _enable_core_then_wait(enemy, finished_cb))
  return tw


func _execute_directional_movement(enemy: Node2D, ai: Node, finished_cb: Callable):
  var direction_vector = _get_direction_vector(enemy, ai)
  var start_position = enemy.global_position
  var target_position = start_position + direction_vector * move_speed * move_time

  # Apply movement bounds if enabled
  if use_movement_bounds:
    target_position = _clamp_position_to_bounds(target_position)

  var tw = enemy.create_tween()
  tw.tween_property(enemy, "global_position", target_position, move_time)
  print_debug(
    "EnemyPatternResource: directional move from ",
    start_position,
    " to ",
    target_position,
    " duration ",
    move_time
  )

  # Store movement direction for future use
  if ai and ai.has_method("set_last_movement_direction"):
    ai.set_last_movement_direction(direction_vector)

  if core_to_enable.is_empty():
    tw.tween_callback(finished_cb)
  else:
    tw.tween_callback(func(): _enable_core_then_wait(enemy, finished_cb))
  return tw


func _execute_stay_in_place(enemy: Node2D, finished_cb: Callable):
  print_debug("EnemyPatternResource: staying in place for ", move_time, " seconds")
  if core_to_enable.is_empty():
    enemy.get_tree().create_timer(move_time).timeout.connect(finished_cb)
    return null
  else:
    _enable_core_then_wait(enemy, finished_cb)
    return null


func _get_direction_vector(enemy: Node2D, ai: Node = null) -> Vector2:
  match direction_type:
    DirectionType.FIXED_ANGLE:
      var angle_rad = deg_to_rad(move_angle)
      return Vector2(cos(angle_rad), sin(angle_rad))
    DirectionType.TO_PLAYER:
      var player_pos = _get_player_position(enemy)
      if player_pos != Vector2.ZERO:
        return (player_pos - enemy.global_position).normalized()
      else:
        print_debug("EnemyPatternResource: Player not found, using default direction")
        return Vector2.RIGHT
    DirectionType.AWAY_FROM_PLAYER:
      var player_pos = _get_player_position(enemy)
      if player_pos != Vector2.ZERO:
        return (enemy.global_position - player_pos).normalized()
      else:
        print_debug("EnemyPatternResource: Player not found, using default direction")
        return Vector2.LEFT
    DirectionType.CONTINUE_PREVIOUS:
      if ai and ai.has_method("get_last_movement_direction"):
        var last_direction = ai.get_last_movement_direction()
        if last_direction != Vector2.ZERO:
          print_debug("EnemyPatternResource: Using previous direction: ", last_direction)
          return last_direction
        else:
          print_debug("EnemyPatternResource: No previous direction, using default")
          return Vector2.RIGHT
      else:
        print_debug("EnemyPatternResource: AI doesn't support direction tracking, using default")
        return Vector2.RIGHT
  return Vector2.RIGHT  # デフォルトは右方向


func _get_player_position(enemy: Node2D) -> Vector2:
  var players = enemy.get_tree().get_nodes_in_group("players")
  if players.size() > 0:
    return players[0].global_position
  return Vector2.ZERO


func _clamp_position_to_bounds(position: Vector2) -> Vector2:
  var play_rect = PlayArea.get_play_rect()

  # Convert normalized bounds (0.0-1.0) to actual PlayArea coordinates
  var actual_bounds = Rect2(
    play_rect.position.x + movement_bounds.position.x * play_rect.size.x,
    play_rect.position.y + movement_bounds.position.y * play_rect.size.y,
    movement_bounds.size.x * play_rect.size.x,
    movement_bounds.size.y * play_rect.size.y
  )

  print_debug("EnemyPatternResource: Clamping position ", position, " to bounds ", actual_bounds)
  return Vector2(
    clamp(position.x, actual_bounds.position.x, actual_bounds.position.x + actual_bounds.size.x),
    clamp(position.y, actual_bounds.position.y, actual_bounds.position.y + actual_bounds.size.y)
  )


func _enable_core_then_wait(enemy: Node2D, finished_cb: Callable):
  var slot = enemy.slot.get_node_or_null(core_to_enable)
  if slot:
    slot.set_phased(true)  # 任意：Core 側で発射ON/OFF切替関数
  enemy.get_tree().create_timer(core_duration).timeout.connect(
    func():
      if slot:
        slot.set_phased(false)
      finished_cb.call()
  )


func _handle_animation_change(enemy: Node2D):
  if not change_animation or animation_name.is_empty():
    return

  var animated_sprite = enemy.get_node_or_null("AnimatedSprite2D")
  if not animated_sprite:
    print_debug("EnemyPatternResource: AnimatedSprite2D not found on enemy")
    return

  if not animated_sprite is AnimatedSprite2D:
    print_debug("EnemyPatternResource: Node is not AnimatedSprite2D")
    return

  # Store original animation for restoration
  if restore_animation:
    _original_animation = animated_sprite.animation

  # Check if the animation exists
  if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
    animated_sprite.play(animation_name)
    print_debug("EnemyPatternResource: Changed animation to ", animation_name)
  else:
    print_debug("EnemyPatternResource: Animation '", animation_name, "' not found")


func _on_pattern_complete(enemy: Node2D, original_callback: Callable):
  # Restore original animation if needed
  if restore_animation and change_animation and not _original_animation.is_empty():
    var animated_sprite = enemy.get_node_or_null("AnimatedSprite2D")
    if animated_sprite and animated_sprite is AnimatedSprite2D:
      if (
        animated_sprite.sprite_frames
        and animated_sprite.sprite_frames.has_animation(_original_animation)
      ):
        animated_sprite.play(_original_animation)
        print_debug("EnemyPatternResource: Restored animation to ", _original_animation)

  # Call the original callback
  if enemy and enemy.is_inside_tree():
    original_callback.call()


func _handle_json_dialogue(_dialogue_path: String, finished_cb: Callable):
  print_debug("EnemyPatternResource: dialogue_path ", _dialogue_path)
  var dialogue_data = DialogueConverter.get_dialogue_data_from_path(_dialogue_path)
  if dialogue_data:
    StageSignals.request_dialogue.emit(dialogue_data, finished_cb)
  else:
    print_debug("EnemyPatternResource: dialogue_path not found: ", _dialogue_path)
    finished_cb.call()  # 会話データが見つからない場合は即座に続行
