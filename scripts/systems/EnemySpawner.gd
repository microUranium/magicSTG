extends Node
class_name EnemySpawner

#----------------------------------------------------------------------
# Signals
#----------------------------------------------------------------------
signal wave_finished  # WaveData 1 本の再生完了
signal layer_finished(layer_id: String)  # 単一レイヤーの再生完了

#----------------------------------------------------------------------
# Export / Tweak
#----------------------------------------------------------------------
@export var max_concurrent := 20  # 同時出現上限（全 Wave 共用）
@export var line_horiz_spacing := 48.0  # LINE_HORIZ の横間隔

#----------------------------------------------------------------------
# Runtime
#----------------------------------------------------------------------
# 旧システム用（互換性維持）
var _spawn_queue: Array[SpawnEvent] = []  # 今再生中 Wave の SpawnEvent キュー
var _current_event: SpawnEvent = null  # 進行中のイベント
var _event_counter: int = 0  # そのイベントで何体出したか
var _event_timer: SceneTreeTimer = null

# 新システム用（レイヤー対応）
var _layer_queues: Dictionary = {}  # layer_id -> Array[SpawnEvent]
var _layer_states: Dictionary = {}  # layer_id -> LayerState
var _active_layers: Array[String] = []  # 現在アクティブなレイヤーID


class LayerState:
  var layer_id: String
  var spawn_queue: Array[SpawnEvent]
  var current_event: SpawnEvent = null
  var event_counter: int = 0
  var event_timer: SceneTreeTimer = null
  var is_active: bool = false
  var spawned_enemies: Array[Node] = []  # このレイヤーで生成した敵のリスト
  var spawn_events_completed: bool = false  # SpawnEvent全て完了したか

  func _init(id: String, events: Array[SpawnEvent]):
    layer_id = id
    spawn_queue = events.duplicate()


#----------------------------------------------------------------------
# Public API
#----------------------------------------------------------------------
func start_wave(events: Array[SpawnEvent]) -> void:
  _spawn_queue = events.duplicate()
  _play_next_event()


func start_layer(layer_id: String, events: Array[SpawnEvent]) -> void:
  if _layer_states.has(layer_id):
    push_warning("EnemySpawner: Layer '%s' already exists" % layer_id)
    return

  var layer_state := LayerState.new(layer_id, events)
  _layer_states[layer_id] = layer_state
  _active_layers.append(layer_id)

  print_debug("EnemySpawner: Starting layer '%s' with %d events" % [layer_id, events.size()])
  _play_next_layer_event(layer_state)


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


# レイヤー用イベント処理
func _play_next_layer_event(layer_state: LayerState) -> void:
  if layer_state.spawn_queue.is_empty():
    layer_state.spawn_events_completed = true
    _check_layer_clear(layer_state.layer_id)
    return

  layer_state.current_event = layer_state.spawn_queue.pop_front()
  layer_state.event_counter = 0
  layer_state.is_active = true

  if layer_state.current_event.pattern == SpawnEvent.Pattern.FROM_TOP_SPACING:
    _spawn_layer_from_top_spacing(layer_state)
    _play_next_layer_event(layer_state)
    return

  _schedule_next_layer_spawn(layer_state, 0.001)


func _schedule_next_layer_spawn(layer_state: LayerState, delay: float) -> void:
  if layer_state.event_timer:
    layer_state.event_timer = null

  layer_state.event_timer = get_tree().create_timer(delay)
  layer_state.event_timer.timeout.connect(_on_layer_timer_spawn.bind(layer_state))


func _on_layer_timer_spawn(layer_state: LayerState) -> void:
  if not layer_state.is_active or layer_state.current_event == null:
    return

  _spawn_layer_by_pattern(layer_state)

  layer_state.event_counter += 1
  if layer_state.event_counter >= layer_state.current_event.count:
    layer_state.current_event = null
    _play_next_layer_event(layer_state)
  else:
    _schedule_next_layer_spawn(layer_state, layer_state.current_event.interval)


func _spawn_layer_by_pattern(layer_state: LayerState) -> void:
  var ev := layer_state.current_event
  match ev.pattern:
    SpawnEvent.Pattern.SINGLE_RANDOM:
      _spawn_layer_enemy(layer_state, _random_position())
    SpawnEvent.Pattern.BURST_SAME_POS:
      if layer_state.event_counter == 0:
        ev.base_pos = _random_position() if ev.base_pos == Vector2.ZERO else ev.base_pos
      _spawn_layer_enemy(layer_state, ev.base_pos)
    SpawnEvent.Pattern.LINE_HORIZ:
      _spawn_layer_line_horiz(layer_state)
    SpawnEvent.Pattern.FROM_TOP_SPACING:
      _spawn_layer_from_top_spacing(layer_state)
    _:
      push_warning("EnemySpawner: Unknown pattern %s" % ev.pattern)


func _spawn_layer_line_horiz(layer_state: LayerState) -> void:
  var ev := layer_state.current_event
  if layer_state.event_counter == 0:
    var first_x := -32
    var rect := get_viewport().get_visible_rect()
    var y := randf_range(rect.position.y + 32, rect.position.y + rect.size.y / 2)
    ev.base_pos = Vector2(first_x, y)
  var spawn_pos := ev.base_pos + Vector2(line_horiz_spacing * layer_state.event_counter, 0)
  _spawn_layer_enemy(layer_state, spawn_pos)


func _spawn_layer_from_top_spacing(layer_state: LayerState) -> void:
  var ev := layer_state.current_event
  var total = ev.count
  if total <= 0:
    push_warning("EnemySpawner: Invalid count for FROM_TOP_SPACING pattern.")
    return

  var rect := PlayArea.get_play_rect()
  var spacing: float = rect.size.x / float(total + 1)

  for i in range(total):
    var x := rect.position.x + spacing * (i + 1)
    var pos := Vector2(x, rect.position.y - 32)
    _spawn_layer_enemy(layer_state, pos)


func _finish_layer(layer_id: String) -> void:
  if not _layer_states.has(layer_id):
    return

  _layer_states.erase(layer_id)
  _active_layers.erase(layer_id)

  print_debug("EnemySpawner: Layer '%s' finished" % layer_id)
  layer_finished.emit(layer_id)


func _spawn_layer_enemy(layer_state: LayerState, pos: Vector2) -> void:
  if get_tree().get_nodes_in_group("enemies").size() >= max_concurrent:
    return
  if layer_state.current_event.enemy_scenes.is_empty():
    return  # 出現シーン未設定
  var scene: PackedScene = layer_state.current_event.enemy_scenes.pick_random()
  var enemy := scene.instantiate()
  get_tree().current_scene.add_child(enemy)
  enemy.global_position = pos

  # レイヤーの敵リストに追加
  layer_state.spawned_enemies.append(enemy)

  # 敵の死亡を監視（複数の方法で確実に検出）
  if enemy.has_signal("tree_exited"):
    enemy.tree_exited.connect(_on_layer_enemy_destroyed.bind(layer_state.layer_id, enemy))

  # EnemyBaseの死亡シグナルも監視（存在する場合）
  if enemy.has_signal("enemy_died"):
    enemy.enemy_died.connect(_on_layer_enemy_died.bind(layer_state.layer_id, enemy))
  elif enemy.has_method("get_hp_node"):
    # HpNodeの死亡を監視
    var hp_node = enemy.get_hp_node()
    if hp_node and hp_node.has_signal("hp_depleted"):
      hp_node.hp_depleted.connect(_on_layer_enemy_died.bind(layer_state.layer_id, enemy))


func _on_layer_enemy_destroyed(layer_id: String, enemy: Node) -> void:
  if not _layer_states.has(layer_id):
    return

  var layer_state := _layer_states[layer_id] as LayerState

  # 敵が実際に削除されるかどうかを確認
  if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
    layer_state.spawned_enemies.erase(enemy)
    print_debug(
      (
        "EnemySpawner: Enemy destroyed in layer '%s', remaining: %d"
        % [layer_id, layer_state.spawned_enemies.size()]
      )
    )

    # SpawnEvent完了済みかつ敵がすべて倒されたかチェック
    if layer_state.spawn_events_completed:
      _check_layer_clear(layer_id)
  else:
    # 敵がまだ有効な場合は誤った呼び出し（フェーズ切り替えなど）
    print_debug(
      "EnemySpawner: False enemy destroy signal for layer '%s' - enemy still valid" % layer_id
    )


func _on_layer_enemy_died(layer_id: String, enemy: Node) -> void:
  if not _layer_states.has(layer_id):
    return

  var layer_state := _layer_states[layer_id] as LayerState
  layer_state.spawned_enemies.erase(enemy)
  print_debug(
    (
      "EnemySpawner: Enemy died in layer '%s', remaining: %d"
      % [layer_id, layer_state.spawned_enemies.size()]
    )
  )

  # SpawnEvent完了済みかつ敵がすべて倒されたかチェック
  if layer_state.spawn_events_completed:
    _check_layer_clear(layer_id)


func _check_layer_clear(layer_id: String) -> void:
  if not _layer_states.has(layer_id):
    return

  var layer_state := _layer_states[layer_id] as LayerState

  # 生存している敵をフィルタリング（無効なNodeを除去）
  var alive_enemies: Array[Node] = []
  for enemy in layer_state.spawned_enemies:
    if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
      alive_enemies.append(enemy)
  layer_state.spawned_enemies = alive_enemies

  print_debug(
    (
      "EnemySpawner: Checking layer '%s' clear, spawn events completed: %s, enemies alive: %d"
      % [layer_id, layer_state.spawn_events_completed, layer_state.spawned_enemies.size()]
    )
  )

  # SpawnEvent完了 & 生存敵0 ⇒ レイヤー完了
  if layer_state.spawn_events_completed and layer_state.spawned_enemies.is_empty():
    _finish_layer(layer_id)
  else:
    # 敵残カウントを監視して再試行
    await get_tree().create_timer(0.5).timeout
    _check_layer_clear(layer_id)


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
  print_debug(
    (
      "EnemySpawner: Checking wave clear, spawn queue size: %d, enemies alive: %d"
      % [_spawn_queue.size(), get_tree().get_nodes_in_group("enemies").size()]
    )
  )
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
