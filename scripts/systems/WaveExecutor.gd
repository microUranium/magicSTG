extends Node
class_name WaveExecutor

signal wave_completed
signal wave_failed
signal layer_started(layer_index: int)
signal layer_completed(layer_index: int)

@export var enemy_spawner_path: NodePath

var _enemy_spawner: EnemySpawner
var _current_layers: Array[Dictionary] = []
var _active_layer_timers: Array[SceneTreeTimer] = []
var _layer_states: Array[String] = []  # "pending", "executing", "completed"
var _completed_layers: int = 0
var _is_executing: bool = false
var _is_paused: bool = false


func _ready() -> void:
  if enemy_spawner_path:
    _enemy_spawner = get_node_or_null(enemy_spawner_path)
    if _enemy_spawner:
      _enemy_spawner.wave_finished.connect(_on_spawner_wave_finished)
      _enemy_spawner.layer_finished.connect(_on_layer_finished)


func set_enemy_spawner(spawner: EnemySpawner) -> void:
  """外部からのEnemySpawner設定"""
  if spawner and _enemy_spawner != spawner:
    _enemy_spawner = spawner
    if not _enemy_spawner.wave_finished.is_connected(_on_spawner_wave_finished):
      _enemy_spawner.wave_finished.connect(_on_spawner_wave_finished)
    if not _enemy_spawner.layer_finished.is_connected(_on_layer_finished):
      _enemy_spawner.layer_finished.connect(_on_layer_finished)


func execute_wave_template(template_data: Dictionary) -> bool:
  if _is_executing:
    push_warning("WaveExecutor: Already executing a wave")
    return false

  if not _enemy_spawner:
    push_error("WaveExecutor: EnemySpawner not found")
    return false

  var layers_raw = template_data.get("layers", [])
  var layers: Array[Dictionary] = []
  for layer in layers_raw:
    if layer is Dictionary:
      layers.append(layer)
  if layers.is_empty():
    push_warning("WaveExecutor: No layers in wave template")
    return false

  _current_layers = layers
  _active_layer_timers.clear()
  _layer_states.clear()
  _completed_layers = 0
  _is_executing = true

  # 全レイヤーの状態を初期化
  for i in range(layers.size()):
    _layer_states.append("pending")

  print_debug("WaveExecutor: Starting wave with %d layers" % layers.size())

  for i in range(layers.size()):
    var layer := layers[i] as Dictionary
    var delay: float = layer.get("delay", 0.0)

    if delay > 0.0:
      var timer := get_tree().create_timer(delay)
      _active_layer_timers.append(timer)
      timer.timeout.connect(_execute_layer.bind(i))
    else:
      _execute_layer(i)

  return true


func _execute_layer(layer_index: int) -> void:
  if not _is_executing or _is_paused:
    return

  if layer_index >= _current_layers.size():
    push_warning("WaveExecutor: Invalid layer index %d" % layer_index)
    return

  if _layer_states[layer_index] != "pending":
    return  # 既に実行中または完了済み

  _layer_states[layer_index] = "executing"
  var layer := _current_layers[layer_index]
  layer_started.emit(layer_index)

  print_debug("WaveExecutor: Executing layer %d" % layer_index)

  # EnemySpawnerのレイヤー機能を使用
  var spawn_events := _convert_layer_to_spawn_events(layer)
  if spawn_events.is_empty():
    _on_layer_completed(layer_index)
    return

  var layer_id := "layer_%d" % layer_index
  _enemy_spawner.start_layer(layer_id, spawn_events)


func _convert_layer_to_spawn_events(layer: Dictionary) -> Array[SpawnEvent]:
  var spawn_events: Array[SpawnEvent] = []

  var enemy_name: String = layer.get("enemy", "")
  var count: int = layer.get("count", 1)
  var pattern_name: String = layer.get("pattern", "single_random")
  var interval: float = layer.get("interval", 0.5)

  var enemy_data := GameDataRegistry.get_enemy_data(enemy_name)
  if enemy_data.is_empty():
    push_warning("WaveExecutor: Enemy '%s' not found" % enemy_name)
    return spawn_events

  var pattern_data := GameDataRegistry.get_spawn_pattern(pattern_name)
  if pattern_data.is_empty():
    push_warning("WaveExecutor: Spawn pattern '%s' not found" % pattern_name)
    return spawn_events

  var scene_path: String = enemy_data.get("scene_path", "")
  if scene_path.is_empty():
    push_warning("WaveExecutor: No scene path for enemy '%s'" % enemy_name)
    return spawn_events

  var enemy_scene := load(scene_path) as PackedScene
  if not enemy_scene:
    push_error("WaveExecutor: Failed to load enemy scene '%s'" % scene_path)
    return spawn_events

  var spawn_event := SpawnEvent.new()
  spawn_event.enemy_scenes = [enemy_scene]
  spawn_event.count = count
  spawn_event.interval = interval
  spawn_event.pattern = _get_spawn_event_pattern_enum(pattern_name)
  spawn_event.base_pos = Vector2.ZERO

  spawn_events.append(spawn_event)
  return spawn_events


func _get_spawn_event_pattern_enum(pattern_name: String) -> int:
  match pattern_name:
    "single_random":
      return SpawnEvent.Pattern.SINGLE_RANDOM
    "burst_same_pos":
      return SpawnEvent.Pattern.BURST_SAME_POS
    "line_horiz":
      return SpawnEvent.Pattern.LINE_HORIZ
    "from_top_spacing":
      return SpawnEvent.Pattern.FROM_TOP_SPACING
    _:
      push_warning("WaveExecutor: Unknown pattern '%s', using SINGLE_RANDOM" % pattern_name)
      return SpawnEvent.Pattern.SINGLE_RANDOM


func _on_spawner_wave_finished() -> void:
  # 旧システム用（互換性維持）
  _on_layer_completed(_get_current_layer_index())


func _on_layer_finished(layer_id: String) -> void:
  # 新システム用（レイヤー対応）
  var layer_index := _extract_layer_index(layer_id)
  if layer_index >= 0:
    _on_layer_completed(layer_index)


func _extract_layer_index(layer_id: String) -> int:
  if layer_id.begins_with("layer_"):
    var index_str := layer_id.substr(6)
    return index_str.to_int()
  return -1


func _get_current_layer_index() -> int:
  return _completed_layers


func _on_layer_completed(layer_index: int) -> void:
  if not _is_executing:
    return

  layer_completed.emit(layer_index)
  _completed_layers += 1

  print_debug(
    (
      "WaveExecutor: Layer %d completed (%d/%d)"
      % [layer_index, _completed_layers, _current_layers.size()]
    )
  )

  if _completed_layers >= _current_layers.size():
    _complete_wave()


func _complete_wave() -> void:
  print_debug("WaveExecutor: Wave completed")
  _cleanup_wave()
  wave_completed.emit()


func _fail_wave() -> void:
  print_debug("WaveExecutor: Wave failed")
  _cleanup_wave()
  wave_failed.emit()


func _cleanup_wave() -> void:
  _is_executing = false
  _current_layers.clear()
  _active_layer_timers.clear()
  _layer_states.clear()
  _completed_layers = 0


func stop_current_wave() -> void:
  if _is_executing:
    print_debug("WaveExecutor: Stopping current wave")
    _cleanup_wave()


func set_paused(paused: bool) -> void:
  _is_paused = paused
  print_debug("WaveExecutor: Paused = %s" % _is_paused)


func is_executing() -> bool:
  return _is_executing


func is_paused() -> bool:
  return _is_paused


func get_current_layers() -> Array[Dictionary]:
  return _current_layers.duplicate()


func get_completed_layers_count() -> int:
  return _completed_layers
