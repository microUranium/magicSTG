extends Node
class_name EnemySpawner

#----------------------------------------------------------------------
# Signals
#----------------------------------------------------------------------
signal wave_finished  # WaveData 1 本の再生完了

#----------------------------------------------------------------------
# Export / Tweak
#----------------------------------------------------------------------
@export var max_concurrent := 20  # 同時出現上限（全 Wave 共用）
@export var line_horiz_spacing := 48.0  # LINE_HORIZ の横間隔

#----------------------------------------------------------------------
# Runtime
#----------------------------------------------------------------------
var _spawn_queue: Array[SpawnEvent] = []  # 今再生中 Wave の SpawnEvent キュー
var _current_event: SpawnEvent = null  # 進行中のイベント
var _event_counter: int = 0  # そのイベントで何体出したか
var _event_timer: SceneTreeTimer = null


#----------------------------------------------------------------------
# Public API
#----------------------------------------------------------------------
func start_wave(events: Array[SpawnEvent]) -> void:
  _spawn_queue = events.duplicate()
  _play_next_event()


#----------------------------------------------------------------------
# Internal – Event 再生管理
#----------------------------------------------------------------------
func _play_next_event() -> void:
  if _spawn_queue.is_empty():
    _check_wave_clear()
    return

  _current_event = _spawn_queue.pop_front()
  _event_counter = 0
  if _current_event.pattern == SpawnEvent.Pattern.FROM_TOP_SPACING:
    _spawn_from_top_spacing(_current_event)
    _play_next_event()
    return

  _schedule_next_spawn(0.001)  # 即座に 1 体目


func _schedule_next_spawn(delay: float) -> void:
  if _event_timer:  # 既存タイマーが残っていれば破棄
    _event_timer = null
  _event_timer = get_tree().create_timer(delay)
  _event_timer.timeout.connect(_on_timer_spawn)


func _on_timer_spawn() -> void:
  if _current_event == null:
    return

  _spawn_by_pattern(_current_event)

  _event_counter += 1
  if _event_counter >= _current_event.count:
    _current_event = null
    _play_next_event()  # 次の SpawnEvent
  else:
    _schedule_next_spawn(_current_event.interval)


#----------------------------------------------------------------------
# Pattern Dispatcher
#----------------------------------------------------------------------
func _spawn_by_pattern(ev: SpawnEvent) -> void:
  match ev.pattern:
    SpawnEvent.Pattern.SINGLE_RANDOM:
      _spawn_enemy(_random_position())
    SpawnEvent.Pattern.BURST_SAME_POS:
      if _event_counter == 0:
        ev.base_pos = _random_position() if ev.base_pos == Vector2.ZERO else ev.base_pos
      _spawn_enemy(ev.base_pos)
    SpawnEvent.Pattern.LINE_HORIZ:
      _spawn_line_horiz(ev)
    SpawnEvent.Pattern.FROM_TOP_SPACING:
      _spawn_from_top_spacing(ev)
    _:
      push_warning("EnemySpawner: Unknown pattern %s" % ev.pattern)


#----------------------------------------------------------------------
# LINE_HORIZ 実装
#----------------------------------------------------------------------
func _spawn_line_horiz(ev: SpawnEvent) -> void:
  # 横一列を左→右へ生成（最初の 1 体の位置はランダム画面外）
  if _event_counter == 0:
    var first_x := -32  # 画面外左
    var rect := get_viewport().get_visible_rect()
    var y := randf_range(rect.position.y + 32, rect.position.y + rect.size.y / 2)
    ev.base_pos = Vector2(first_x, y)
  var spawn_pos := ev.base_pos + Vector2(line_horiz_spacing * _event_counter, 0)
  _spawn_enemy(spawn_pos)


func _spawn_from_top_spacing(ev: SpawnEvent) -> void:
  # 上から等間隔で出現
  var total = ev.count
  if total <= 0:
    push_warning("EnemySpawner: Invalid count for FROM_TOP_SPACING pattern.")
    return

  var rect := PlayArea.get_play_rect()
  var spacing: float = rect.size.x / float(total + 1)  # 左端～右端を N+1 分割

  for i in range(total):
    var x := rect.position.x + spacing * (i + 1)
    var pos := Vector2(x, rect.position.y - 32)  # 上端から出現
    _spawn_enemy(pos)


#----------------------------------------------------------------------
# Enemy Instantiation
#----------------------------------------------------------------------
func _spawn_enemy(pos: Vector2) -> void:
  if get_tree().get_nodes_in_group("enemies").size() >= max_concurrent:
    return
  if _current_event.enemy_scenes.is_empty():
    return  # 出現シーン未設定
  var scene: PackedScene = _current_event.enemy_scenes.pick_random()
  var enemy := scene.instantiate()
  get_tree().current_scene.add_child(enemy)
  enemy.global_position = pos


#----------------------------------------------------------------------
# Wave Clear 判定
#----------------------------------------------------------------------
func _check_wave_clear() -> void:
  # spawn_queue が空 & 生存敵グループも 0 ⇒ Wave 完了
  if _spawn_queue.is_empty() and get_tree().get_nodes_in_group("enemies").is_empty():
    emit_signal("wave_finished")
  else:
    # 敵残カウントを監視して再試行
    await get_tree().create_timer(0.5).timeout
    _check_wave_clear()


#----------------------------------------------------------------------
# 位置ユーティリティ
#----------------------------------------------------------------------
func _random_position() -> Vector2:
  var rect := PlayArea.get_play_rect()
  var side := randi() % 3  # 0:上,1:左,2:右
  var y_limit := rect.size.y / 2

  match side:
    0:
      return Vector2(randf_range(rect.position.x, rect.end.x), rect.position.y - 32)
    1:
      return Vector2(rect.position.x - 32, randf_range(rect.position.y, rect.position.y + y_limit))
    2:
      return Vector2(rect.end.x + 32, randf_range(rect.position.y, rect.position.y + y_limit))
  return Vector2.ZERO
