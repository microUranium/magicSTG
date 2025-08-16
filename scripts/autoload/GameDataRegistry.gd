extends Node

var stage_configs: Dictionary = {}
var wave_templates: Dictionary = {}
var enemies: Dictionary = {}
var spawn_patterns: Dictionary = {}
var dialogues: Dictionary = {}
var wave_pools: Dictionary = {}

var _data_loaded: bool = false


func _ready() -> void:
  load_stage_data()


func load_stage_data(_data: Dictionary = {}) -> bool:
  var data: Dictionary = _data if _data else parse_json_data("res://resources/data/stage_data.json")

  if data == null:
    push_error("GameDataRegistry: Invalid JSON structure")
    return false
  stage_configs = data.get("stage_configs", {})
  wave_templates = data.get("wave_templates", {})
  enemies = data.get("enemies", {})
  spawn_patterns = data.get("spawn_patterns", {})
  dialogues = data.get("dialogues", {})
  wave_pools = data.get("wave_pools", {})

  _data_loaded = true
  print_debug(
    (
      "GameDataRegistry: Loaded %d stage configs, %d wave templates, %d enemies, %d spawn patterns, %d dialogues, %d wave pools"
      % [
        stage_configs.size(),
        wave_templates.size(),
        enemies.size(),
        spawn_patterns.size(),
        dialogues.size(),
        wave_pools.size()
      ]
    )
  )

  return true


func is_data_loaded() -> bool:
  return _data_loaded


func get_wave_template(template_name: String) -> Dictionary:
  if not wave_templates.has(template_name):
    push_warning("GameDataRegistry: Wave template '%s' not found" % template_name)
    return {}
  return wave_templates[template_name]


func get_enemy_data(enemy_name: String) -> Dictionary:
  if not enemies.has(enemy_name):
    push_warning("GameDataRegistry: Enemy '%s' not found" % enemy_name)
    return {}
  return enemies[enemy_name]


func get_spawn_pattern(pattern_name: String) -> Dictionary:
  if not spawn_patterns.has(pattern_name):
    push_warning("GameDataRegistry: Spawn pattern '%s' not found" % pattern_name)
    return {}
  return spawn_patterns[pattern_name]


func get_stage_config(stage_name: String) -> Dictionary:
  if not stage_configs.has(stage_name):
    push_warning("GameDataRegistry: Stage config '%s' not found" % stage_name)
    return {}
  return stage_configs[stage_name]


func get_dialogue_data(dialogue_path: String) -> Array:
  var parts := dialogue_path.split(".")
  if parts.size() != 2:
    push_warning(
      (
        "GameDataRegistry: Invalid dialogue path format '%s'. Expected 'pool.dialogue_id'"
        % dialogue_path
      )
    )
    return []
  var pool_name := parts[0]
  var dialogue_id := parts[1]

  if not dialogues.has(pool_name):
    push_warning("GameDataRegistry: Dialogue pool '%s' not found" % pool_name)
    return []
  var pool := dialogues[pool_name] as Dictionary
  if not pool.has(dialogue_id):
    push_warning(
      "GameDataRegistry: Dialogue '%s' not found in pool '%s'" % [dialogue_id, pool_name]
    )
    return []
  return pool[dialogue_id] as Array


func get_all_wave_template_names() -> Array[String]:
  var names: Array[String] = []
  for name in wave_templates.keys():
    names.append(name)
  return names


func get_all_enemy_names() -> Array[String]:
  var names: Array[String] = []
  for name in enemies.keys():
    names.append(name)
  return names


func get_waves_by_pool(pool_name: String) -> Dictionary:
  """指定プールに属するウェーブテンプレートを取得"""
  var pool_waves: Dictionary = {}

  for template_name in wave_templates.keys():
    var template_data = wave_templates[template_name]
    if template_data.get("pool", "") == pool_name:
      pool_waves[template_name] = template_data

  return pool_waves


func get_wave_pool_info(pool_name: String) -> Dictionary:
  """ウェーブプール情報を取得"""
  if not wave_pools.has(pool_name):
    push_warning("GameDataRegistry: Wave pool '%s' not found" % pool_name)
    return {}
  return wave_pools[pool_name]


func get_all_pool_names() -> Array[String]:
  """全プール名を取得"""
  var names: Array[String] = []
  for name in wave_pools.keys():
    names.append(name)
  return names


func validate_pool_waves() -> bool:
  """プール設定の妥当性チェック"""
  var valid := true

  for template_name in wave_templates.keys():
    var template_data = wave_templates[template_name]
    var pool_name: String = template_data.get("pool", "")

    if not pool_name.is_empty() and not wave_pools.has(pool_name):
      push_warning(
        (
          "GameDataRegistry: Wave template '%s' references unknown pool '%s'"
          % [template_name, pool_name]
        )
      )
      valid = false

  return valid


func reload_data() -> bool:
  _data_loaded = false
  stage_configs.clear()
  wave_templates.clear()
  enemies.clear()
  spawn_patterns.clear()
  dialogues.clear()
  wave_pools.clear()
  return load_stage_data()


static func parse_json_data(file_path: String) -> Dictionary:
  var file := FileAccess.open(file_path, FileAccess.READ)
  if file == null:
    push_error("GameDataRegistry: Failed to open stage data file at %s" % file_path)
    return {}

  var json_text := file.get_as_text()
  file.close()

  var json := JSON.new()
  var parse_result := json.parse(json_text)

  if parse_result != OK:
    push_error(
      (
        "GameDataRegistry: JSON parse error at line %d: %s"
        % [json.get_error_line(), json.get_error_message()]
      )
    )
    return {}

  return json.data as Dictionary


static func parse_json_data_from_string(json_string: String) -> Dictionary:
  var json := JSON.new()
  var parse_result := json.parse(json_string)

  if parse_result != OK:
    push_error(
      (
        "GameDataRegistry: JSON parse error at line %d: %s"
        % [json.get_error_line(), json.get_error_message()]
      )
    )
    return {}

  return json.data as Dictionary
