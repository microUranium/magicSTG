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
@export var max_concurrent := 100  # 同時出現上限（全 Wave 共用）
@export var line_horiz_spacing := 48.0  # LINE_HORIZ の横間隔

#----------------------------------------------------------------------
# Runtime
#----------------------------------------------------------------------
# 新システム用（レイヤー対応）
var _layer_queues: Dictionary = {}  # layer_id -> Array[SpawnEvent]
var _layer_states: Dictionary = {}  # layer_id -> LayerState
var _active_layers: Array[String] = []  # 現在アクティブなレイヤーID

@onready var enemy_layer: Node = get_tree().current_scene.get_node("EnemyLayer")  # 敵を生成するレイヤー


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
func start_layer(layer_id: String, events: Array[SpawnEvent]) -> void:
  if _layer_states.has(layer_id):
    push_warning("EnemySpawner: Layer '%s' already exists" % layer_id)
    return

  var layer_state := LayerState.new(layer_id, events)
  _layer_states[layer_id] = layer_state
  _active_layers.append(layer_id)

  _play_next_layer_event(layer_state)


#----------------------------------------------------------------------
# Internal – Event 再生管理
#----------------------------------------------------------------------
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
    SpawnEvent.Pattern.PERIMETER_SEQUENTIAL:
      _spawn_layer_perimeter_sequential(layer_state)
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


func _spawn_layer_perimeter_sequential(layer_state: LayerState) -> void:
  var ev := layer_state.current_event

  # 初回のみ周囲座標を事前計算
  if layer_state.event_counter == 0:
    var play_rect = PlayArea.get_play_rect()
    var params = _get_perimeter_params(ev.parameters)

    # パラメータ妥当性チェック
    if not PerimeterSpawnUtil.validate_perimeter_params(params):
      push_warning("EnemySpawner: Invalid perimeter parameters, using defaults")
      params = PerimeterSpawnUtil.get_default_params()

    var positions = PerimeterSpawnUtil.calculate_perimeter_positions(ev.count, params, play_rect)

    # LayerStateに座標配列を保存
    ev.parameters["_calculated_positions"] = positions

  # 事前計算した座標からスポーン
  var positions = ev.parameters.get("_calculated_positions", [])
  if layer_state.event_counter < positions.size():
    var spawn_pos = positions[layer_state.event_counter]
    _spawn_layer_enemy(layer_state, spawn_pos)
  else:
    push_warning("EnemySpawner: Perimeter spawn index out of range")


func _get_perimeter_params(params: Dictionary) -> Dictionary:
  # デフォルト値を取得
  var default_params = PerimeterSpawnUtil.get_default_params()

  # ユーザー指定値でオーバーライド
  for key in params.keys():
    if key in default_params:
      default_params[key] = params[key]

  return default_params


func _finish_layer(layer_id: String) -> void:
  if not _layer_states.has(layer_id):
    return

  _layer_states.erase(layer_id)
  _active_layers.erase(layer_id)

  layer_finished.emit(layer_id)


func _spawn_layer_enemy(layer_state: LayerState, pos: Vector2) -> void:
  if get_tree().get_nodes_in_group("enemies").size() >= max_concurrent:
    return
  if layer_state.current_event.enemy_scenes.is_empty():
    return  # 出現シーン未設定
  var scene: PackedScene = layer_state.current_event.enemy_scenes.pick_random()
  var enemy := scene.instantiate()
  if layer_state.current_event.parameters:
    for param_name in layer_state.current_event.parameters.keys():
      var param_value = layer_state.current_event.parameters[param_name]
      if enemy.has_method("set_parameter"):
        enemy.set_parameter(param_name, str(param_value))
      else:
        push_warning("EnemySpawner: Enemy %s does not support set_parameter" % enemy.name)
  if enemy_layer:
    enemy_layer.add_child(enemy)
  else:
    push_warning("EnemySpawner: EnemyLayer not found, adding to current scene")
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

  # SpawnEvent完了 & 生存敵0 ⇒ レイヤー完了
  if layer_state.spawn_events_completed and layer_state.spawned_enemies.is_empty():
    _finish_layer(layer_id)
  else:
    # 敵残カウントを監視して再試行
    if is_inside_tree():
      await get_tree().create_timer(0.5).timeout
    _check_layer_clear(layer_id)


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
