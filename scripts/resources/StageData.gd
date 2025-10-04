extends Resource
class_name StageData

@export var stage_name: String = ""
@export var chapter_id: String = ""
@export var stage_id: String = ""
@export var is_seed_fixed: bool = true
@export var fixed_seed: String = ""
@export var is_unlocked: bool = false
@export var dialogue_enabled: bool = true
@export var random_seed_pools: Array[Dictionary] = []  # e.g., [{"pool": "stage1", "count": 5}, {"pool": "stage1_boss", "count": 1}]


func get_seed_for_play() -> String:
  if is_seed_fixed and not fixed_seed.is_empty():
    return fixed_seed
  elif not is_seed_fixed and random_seed_pools.size() > 0:
    return RandomSeedGenerator.generate_seed_with_pools(random_seed_pools)
  return RandomSeedGenerator.generate_random_seed()


func can_start() -> bool:
  return is_unlocked
