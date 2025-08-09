extends Node

signal seed_generated(seed_value: String)

var _current_seed: String = ""
var _rng: RandomNumberGenerator


func _ready() -> void:
  _rng = RandomNumberGenerator.new()
  _rng.randomize()


func get_current_seed() -> String:
  return _current_seed


func set_current_seed(seed_value: String) -> void:
  _current_seed = seed_value
  seed_generated.emit(_current_seed)


func generate_random_seed_for_stage(stage_config: Dictionary) -> String:
  """ステージ設定に基づいてランダムなシード値を生成"""
  var total_waves: int = stage_config.get("total_waves", 5)
  var pool_weights: Dictionary = stage_config.get("pool_weights", {})

  if pool_weights.is_empty():
    push_warning("RandomSeedGenerator: No pool weights specified, using default")
    pool_weights = _get_default_pool_weights()

  var seed_parts: Array[String] = []

  for i in range(total_waves):
    var selected_pool := _select_pool_by_weight(pool_weights)
    var wave_template := _select_wave_from_pool(selected_pool)

    if not wave_template.is_empty():
      seed_parts.append(wave_template)

  _current_seed = "-".join(seed_parts)
  seed_generated.emit(_current_seed)

  print_debug(
    "RandomSeedGenerator: Generated seed '%s' with %d waves" % [_current_seed, total_waves]
  )
  return _current_seed


func generate_seed_with_pools(pool_sequence: Array) -> String:
  """プール順序指定でシード値を生成
  pool_sequence例: [{'pool': 'stage1_easy', 'count': 2}, {'pool': 'stage1_boss', 'count': 1}]
  """
  var seed_parts: Array[String] = []

  for pool_config in pool_sequence:
    var pool_name: String = pool_config.get("pool", "")
    var count: int = pool_config.get("count", 1)

    if pool_name.is_empty():
      continue

    for i in range(count):
      var wave_template := _select_wave_from_pool(pool_name)
      if not wave_template.is_empty():
        seed_parts.append(wave_template)

  _current_seed = "-".join(seed_parts)
  seed_generated.emit(_current_seed)

  print_debug("RandomSeedGenerator: Generated structured seed '%s'" % _current_seed)
  return _current_seed


func _select_pool_by_weight(pool_weights: Dictionary) -> String:
  """重み付きランダム選択でプールを選出"""
  var total_weight := 0
  for weight in pool_weights.values():
    total_weight += weight as int

  if total_weight <= 0:
    return pool_weights.keys()[0] if not pool_weights.is_empty() else ""

  var random_value := _rng.randi_range(1, total_weight)
  var current_weight := 0

  for pool_name in pool_weights.keys():
    current_weight += pool_weights[pool_name] as int
    if random_value <= current_weight:
      return pool_name

  return pool_weights.keys()[-1] if not pool_weights.is_empty() else ""


func _select_wave_from_pool(pool_name: String) -> String:
  """指定プールから重み付きランダム選択でウェーブテンプレートを選出"""
  if not GameDataRegistry.is_data_loaded():
    push_error("RandomSeedGenerator: GameDataRegistry not loaded")
    return ""

  var pool_waves: Dictionary = GameDataRegistry.get_waves_by_pool(pool_name)
  if pool_waves.is_empty():
    push_warning("RandomSeedGenerator: No waves found in pool '%s'" % pool_name)
    return ""

  # 重みベースの選択
  var total_weight := 0
  for wave_data in pool_waves.values():
    var weight = wave_data.get("weight", 1)
    # 型安全性を確保（不正な値は1に変換）
    if weight is int:
      total_weight += weight
    elif weight is String and weight.is_valid_int():
      total_weight += weight.to_int()
    else:
      total_weight += 1

  if total_weight <= 0:
    return pool_waves.keys()[0]

  var random_value := _rng.randi_range(1, total_weight)
  var current_weight := 0

  for wave_name in pool_waves.keys():
    var wave_data = pool_waves[wave_name]
    var weight = wave_data.get("weight", 1)
    # 型安全性を確保（不正な値は1に変換）
    if weight is int:
      current_weight += weight
    elif weight is String and weight.is_valid_int():
      current_weight += weight.to_int()
    else:
      current_weight += 1

    if random_value <= current_weight:
      return wave_name

  return pool_waves.keys()[-1]


func _get_default_pool_weights() -> Dictionary:
  """デフォルトプール重み設定"""
  return {
    "stage1_easy": 30,
    "stage1_medium": 25,
    "stage1_hard": 15,
    "stage1_combined": 20,
    "stage1_boss": 10
  }


func clear_seed() -> void:
  _current_seed = ""


func set_seed(seed: int) -> void:
  """RNG シード設定（再現性のため）"""
  _rng.seed = seed
