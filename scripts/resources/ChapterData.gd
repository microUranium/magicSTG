extends Resource
class_name ChapterData

@export var chapter_id: String = ""
@export var chapter_name: String = ""
@export var stages: Array[StageData] = []
@export var is_unlocked: bool = false
@export var background_texture: Texture2D


func get_stage_by_id(stage_id: String) -> StageData:
  for stage in stages:
    if stage.stage_id == stage_id:
      return stage
  return null


func get_unlocked_stages() -> Array[StageData]:
  var unlocked: Array[StageData] = []
  for stage in stages:
    if stage.is_unlocked:
      unlocked.append(stage)
  return unlocked


func has_unlocked_stages() -> bool:
  for stage in stages:
    if stage.is_unlocked:
      return true
  return false
