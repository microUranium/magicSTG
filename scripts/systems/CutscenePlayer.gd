extends Node
class_name CutscenePlayer
## stage_data.json の "cutscenes" に定義された演出シーケンスを再生する。
##
## ステップ種別:
##   wait            {"time": 秒}
##   fade_out        {"time": 秒}                     画面を暗転させる
##   fade_in         {"time": 秒}                     暗転を解除する
##   set_background  {"texture": "res://..."}         フェードなしで背景を差し替える
##   set_scroll_speed{"speed": 値, "time": 秒}        背景スクロール速度を変更する
##   stop_bgm        {"fade": 秒}
##   spawn_actor     {"id": 名前, "scene": "res://...", "position": [x, y]}
##   move_actor      {"id": 名前, "position": [x, y], "time": 秒}
##   exit_actor      {"id": 名前, "position": [x, y], "time": 秒}  画面外へ退場させて削除
##   despawn_actor   {"id": 名前}
##   move_player     {"position": [x, y], "time": 秒}  time<=0 ならワープ
##   dialogue        {"path": "s5d12.resolution2"}

signal cutscene_finished(cutscene_id: String)

@warning_ignore("unused_signal")
signal _dialogue_step_finished  # ダイアログ完了待ち用（内部）

@export_node_path("Node") var actor_parent_path: NodePath

var _actors: Dictionary = {}
var _current_id: String = ""
var _is_playing: bool = false


func is_playing() -> bool:
  return _is_playing


func play(cutscene_id: String, cutscene_data: Dictionary) -> void:
  """演出を再生する。完了時に cutscene_finished を発火する。"""
  if _is_playing:
    push_warning("CutscenePlayer: Already playing '%s'" % _current_id)
    return

  var steps: Array = cutscene_data.get("steps", [])
  _current_id = cutscene_id
  _is_playing = true

  for step in steps:
    if not _is_playing:  # stop() で中断された
      break
    if not step is Dictionary:
      push_warning("CutscenePlayer: Invalid step in '%s'" % cutscene_id)
      continue
    # 会話終了時にステージ側がポーズを解除するため、ステップごとに掛け直す
    StageSignals.emit_cutscene_pause_requested(true)
    await _execute_step(step as Dictionary)

  _clear_actors()
  _is_playing = false
  StageSignals.emit_cutscene_pause_requested(false)
  cutscene_finished.emit(cutscene_id)
  _current_id = ""


func stop() -> void:
  """再生中の演出を中断する（ステージ終了時など）。"""
  if not _is_playing:
    return
  _is_playing = false


func _execute_step(step: Dictionary) -> void:
  var step_type: String = step.get("type", "")
  match step_type:
    "wait":
      await _wait(_get_time(step, "time"))
    "fade_out":
      await _fade(true, _get_time(step, "time", 0.8))
    "fade_in":
      await _fade(false, _get_time(step, "time", 0.8))
    "set_background":
      _set_background(step.get("texture", ""))
    "set_scroll_speed":
      StageSignals.emit_request_change_background_scroll_speed(
        float(step.get("speed", 0.0)), _get_time(step, "time")
      )
    "stop_bgm":
      StageSignals.emit_bgm_stop_requested(_get_time(step, "fade"))
    "spawn_actor":
      _spawn_actor(step)
    "move_actor":
      await _move_actor(step, false)
    "exit_actor":
      await _move_actor(step, true)
    "despawn_actor":
      _despawn_actor(String(step.get("id", "")))
    "move_player":
      await _move_player(step)
    "dialogue":
      await _play_dialogue(String(step.get("path", "")))
    _:
      push_warning("CutscenePlayer: Unknown step type '%s'" % step_type)


#---------------------------------------------------------------------
# 各ステップの実装
#---------------------------------------------------------------------
func _wait(seconds: float) -> void:
  if seconds <= 0.0:
    return
  await get_tree().create_timer(seconds, false).timeout


func _fade(to_black: bool, duration: float) -> void:
  StageSignals.emit_request_screen_fade(to_black, duration)
  await _wait(duration)


func _set_background(texture_path: String) -> void:
  if texture_path.is_empty():
    push_warning("CutscenePlayer: set_background without texture")
    return
  var texture := load(texture_path) as Texture2D
  if texture == null:
    push_warning("CutscenePlayer: Failed to load background '%s'" % texture_path)
    return
  StageSignals.emit_request_background_texture_change(texture)


func _spawn_actor(step: Dictionary) -> void:
  var actor_id := String(step.get("id", ""))
  var scene_path := String(step.get("scene", ""))
  if actor_id.is_empty() or scene_path.is_empty():
    push_warning("CutscenePlayer: spawn_actor requires 'id' and 'scene'")
    return

  var packed := load(scene_path) as PackedScene
  if packed == null:
    push_warning("CutscenePlayer: Failed to load actor scene '%s'" % scene_path)
    return

  var actor := packed.instantiate() as Node2D
  if actor == null:
    push_warning("CutscenePlayer: Actor scene '%s' is not a Node2D" % scene_path)
    return

  _despawn_actor(actor_id)  # 同じIDが残っていたら置き換える
  _get_actor_parent().add_child(actor)
  actor.global_position = _to_vector2(step.get("position", null), actor.global_position)
  _actors[actor_id] = actor


func _move_actor(step: Dictionary, exit_after_move: bool) -> void:
  var actor := _get_actor(String(step.get("id", "")))
  if actor == null:
    return

  var target := _to_vector2(step.get("position", null), actor.global_position)
  var duration := _get_time(step, "time")

  if exit_after_move:
    _actors.erase(String(step.get("id", "")))
    actor.exit_to(target, duration)
    await _wait(duration)
    return

  var tween := actor.move_to(target, duration)
  if tween:
    await tween.finished


func _despawn_actor(actor_id: String) -> void:
  if not _actors.has(actor_id):
    return
  var actor = _actors[actor_id]
  _actors.erase(actor_id)
  if is_instance_valid(actor):
    actor.queue_free()


func _move_player(step: Dictionary) -> void:
  var player := TargetService.get_player()
  if player == null or not player.has_method("move_to"):
    push_warning("CutscenePlayer: Player not available for move_player")
    return

  var target := _to_vector2(step.get("position", null), player.global_position)
  var tween: Tween = player.move_to(target, _get_time(step, "time"))
  if tween:
    await tween.finished


func _play_dialogue(dialogue_path: String) -> void:
  if dialogue_path.is_empty():
    push_warning("CutscenePlayer: dialogue step without path")
    return

  var dialogue_data := DialogueConverter.get_dialogue_data_from_path(dialogue_path)
  if dialogue_data == null:
    push_warning("CutscenePlayer: Dialogue '%s' not found" % dialogue_path)
    return

  # コールバックが同期的に呼ばれても待ち続けないようにフラグで判定する
  var state := {"finished": false}
  StageSignals.request_dialogue.emit(
    dialogue_data,
    func():
      state["finished"] = true
      _dialogue_step_finished.emit()
  )
  if not state["finished"]:
    await _dialogue_step_finished


#---------------------------------------------------------------------
# ヘルパー
#---------------------------------------------------------------------
func _get_actor(actor_id: String) -> CutsceneActor:
  if not _actors.has(actor_id):
    push_warning("CutscenePlayer: Actor '%s' not found" % actor_id)
    return null
  var actor = _actors[actor_id]
  if not is_instance_valid(actor):
    _actors.erase(actor_id)
    return null
  return actor as CutsceneActor


func _get_actor_parent() -> Node:
  if actor_parent_path:
    var parent := get_node_or_null(actor_parent_path)
    if parent:
      return parent
  return get_parent() if get_parent() else self


func _clear_actors() -> void:
  for actor_id in _actors.keys():
    var actor = _actors[actor_id]
    if is_instance_valid(actor):
      actor.queue_free()
  _actors.clear()


func _get_time(step: Dictionary, key: String, default_value: float = 0.0) -> float:
  return float(step.get(key, default_value))


func _to_vector2(value, fallback: Vector2) -> Vector2:
  if value is Array and (value as Array).size() >= 2:
    return Vector2(float(value[0]), float(value[1]))
  if value is Vector2:
    return value
  return fallback
