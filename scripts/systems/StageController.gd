extends Node
class_name StageController

signal stage_event_started(event_type: String, event_data: Dictionary)
signal stage_event_completed(event_type: String)
signal stage_completed
signal stage_failed

@export var wave_executor_path: NodePath
@export var dialogue_runner_path: NodePath
@export var inter_wave_delay: float = 3.0  # ウェーブ間の待ち時間

var _wave_executor: WaveExecutor
var _dialogue_runner: DialogueRunner
var _current_seed: String = ""
var _event_queue: Array[Dictionary] = []
var _current_event_index: int = 0
var _is_running: bool = false
var _current_dialogue_token: String = ""  # StageController管理のダイアログ識別用


func _ready() -> void:
  if wave_executor_path:
    _wave_executor = get_node_or_null(wave_executor_path)
    if _wave_executor:
      _wave_executor.wave_completed.connect(_on_wave_completed)
      _wave_executor.wave_failed.connect(_on_wave_failed)

  if dialogue_runner_path:
    _dialogue_runner = get_node_or_null(dialogue_runner_path)
    if _dialogue_runner:
      _dialogue_runner.dialogue_finished.connect(_on_dialogue_completed)

  # StageSignalsからの攻撃コア停止要求を処理
  StageSignals.attack_cores_pause_requested.connect(_pause_attack_cores)
  StageSignals.blessings_pause_requested.connect(_pause_blessings)


func set_dependencies(wave_executor: WaveExecutor, dialogue_runner: DialogueRunner) -> void:
  """外部からの依存関係設定"""
  if wave_executor and _wave_executor != wave_executor:
    _wave_executor = wave_executor
    if not _wave_executor.wave_completed.is_connected(_on_wave_completed):
      _wave_executor.wave_completed.connect(_on_wave_completed)
    if not _wave_executor.wave_failed.is_connected(_on_wave_failed):
      _wave_executor.wave_failed.connect(_on_wave_failed)

  if dialogue_runner and _dialogue_runner != dialogue_runner:
    _dialogue_runner = dialogue_runner
    if not _dialogue_runner.dialogue_finished.is_connected(_on_dialogue_completed):
      _dialogue_runner.dialogue_finished.connect(_on_dialogue_completed)


func start_stage(seed_value: String) -> bool:
  if not GameDataRegistry.is_data_loaded():
    push_error("StageController: GameDataRegistry not loaded")
    return false
  _current_seed = seed_value
  _event_queue.clear()
  _current_event_index = 0
  _is_running = true

  if not _parse_seed(seed_value):
    push_error("StageController: Failed to parse seed '%s'" % seed_value)
    return false
  print_debug(
    "StageController: Starting stage with seed '%s', %d events" % [seed_value, _event_queue.size()]
  )
  _pause_attack_cores(false)  # ステージ開始時は攻撃コアを有効化
  _execute_next_event()
  return true


func _parse_seed(seed_value: String) -> bool:
  var parts := seed_value.split("-")
  if parts.is_empty():
    return false
  for part in parts:
    part = part.strip_edges()
    if part.is_empty():
      continue
    if part.begins_with("D"):
      var dialogue_path := part.substr(1)
      var dialogue_data := GameDataRegistry.get_dialogue_data(dialogue_path)
      if dialogue_data.is_empty():
        push_warning("StageController: Dialogue '%s' not found" % dialogue_path)
        continue
      _event_queue.append(
        {"type": "dialogue", "dialogue_path": dialogue_path, "dialogue_data": dialogue_data}
      )
    else:
      var template_data := GameDataRegistry.get_wave_template(part)
      if template_data.is_empty():
        push_warning("StageController: Wave template '%s' not found" % part)
        continue
      _event_queue.append({"type": "wave", "template_name": part, "template_data": template_data})
  return not _event_queue.is_empty()


func _execute_next_event() -> void:
  if not _is_running:
    return
  print_debug(
    "StageController: Executing event %d/%d" % [_current_event_index + 1, _event_queue.size()]
  )
  if _current_event_index >= _event_queue.size():
    _complete_stage()
    return
  var event := _event_queue[_current_event_index]
  var event_type: String = event.get("type", "")

  stage_event_started.emit(event_type, event)

  match event_type:
    "wave":
      _execute_wave_event(event)
    "dialogue":
      _execute_dialogue_event(event)
    _:
      push_warning("StageController: Unknown event type '%s'" % event_type)
      _advance_to_next_event()


func _execute_wave_event(event: Dictionary) -> void:
  if not _wave_executor:
    push_error("StageController: WaveExecutor not found")
    _advance_to_next_event()
    return
  var template_name: String = event.get("template_name", "")
  var template_data: Dictionary = event.get("template_data", {})

  _pause_attack_cores(false)  # ウェーブ開始時は攻撃コアを有効化
  _wave_executor.execute_wave_template(template_data)


func _execute_dialogue_event(event: Dictionary) -> void:
  if not _dialogue_runner:
    push_error("StageController: DialogueRunner not found")
    _advance_to_next_event()
    return

  var dialogue_path: String = event.get("dialogue_path", "")
  var dialogue_data: Array = event.get("dialogue_data", [])

  # StageController管理のダイアログに一意トークンを付与
  _current_dialogue_token = (
    "stage_dialogue_" + str(Time.get_unix_time_from_system()) + "_" + dialogue_path
  )

  print_debug(
    (
      "StageController: Executing stage dialogue '%s' with token '%s'"
      % [dialogue_path, _current_dialogue_token]
    )
  )
  _pause_attack_cores(true)  # ダイアログ開始時は攻撃コアを停止

  # DialogueConverterを使用してデータ変換
  var dialogue_data_obj := DialogueConverter.convert_json_to_dialogue_data(dialogue_data)

  # トークン付きでダイアログ実行（StageManager経由）
  StageSignals.request_dialogue.emit(
    dialogue_data_obj, _on_stage_dialogue_finished.bind(_current_dialogue_token)
  )


func _advance_to_next_event() -> void:
  if not _is_running:
    return
  var current_event := _event_queue[_current_event_index]
  var event_type: String = current_event.get("type", "")
  stage_event_completed.emit(event_type)

  _current_event_index += 1
  _execute_next_event()


func _complete_stage() -> void:
  _is_running = false
  _pause_attack_cores(true)  # ステージ完了時は攻撃コアを停止
  stage_completed.emit()


func _fail_stage() -> void:
  _is_running = false
  _pause_attack_cores(true)  # ステージ失敗時は攻撃コアを停止
  stage_failed.emit()


func _on_wave_completed() -> void:
  print_debug(
    "StageController: Wave completed - waiting %.1f seconds before next event" % inter_wave_delay
  )
  await get_tree().create_timer(inter_wave_delay).timeout
  _advance_to_next_event()


func _on_wave_failed() -> void:
  _fail_stage()


func _on_dialogue_completed(_dialogue_data: DialogueData) -> void:
  _pause_attack_cores(false)
  _pause_blessings(false)
  # 敵などの外部ダイアログ完了は無視（トークン付きコールバックのみ処理）


func _on_stage_dialogue_finished(token: String) -> void:
  # 自分が管理するダイアログの完了のみ処理
  if token == _current_dialogue_token:
    _current_dialogue_token = ""  # トークンをクリア
    _advance_to_next_event()


func stop_stage() -> void:
  _is_running = false
  _pause_attack_cores(true)  # ステージ停止時は攻撃コアを停止
  if _wave_executor:
    _wave_executor.stop_current_wave()


func pause_stage(paused: bool) -> void:
  _pause_attack_cores(paused)  # ステージ一時停止時は攻撃コアも同期
  if _wave_executor:
    _wave_executor.set_paused(paused)


func get_current_seed() -> String:
  return _current_seed


func get_current_event_index() -> int:
  return _current_event_index


func get_total_events() -> int:
  return _event_queue.size()


func is_stage_running() -> bool:
  return _is_running


func _pause_attack_cores(paused: bool) -> void:
  for core in get_tree().get_nodes_in_group("attack_cores"):
    if core.has_method("set_paused"):
      core.set_paused(paused)


func _pause_blessings(paused: bool) -> void:
  for blessing in get_tree().get_nodes_in_group("blessings"):
    if blessing.has_method("set_paused"):
      blessing.set_paused(paused)
