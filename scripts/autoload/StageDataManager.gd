extends Node

signal stage_data_loaded
signal stage_unlocked(chapter_id: String, stage_id: String)
signal chapter_unlocked(chapter_id: String)

const STAGE_DATA_PATH = "res://resources/data/stage_select_data.tres"
var stage_select_data: StageSelectData


func _ready() -> void:
  load_stage_data()


func load_stage_data() -> void:
  if ResourceLoader.exists(STAGE_DATA_PATH):
    stage_select_data = load(STAGE_DATA_PATH) as StageSelectData
    if stage_select_data:
      for chapter in stage_select_data.chapters:
        print_debug(
          (
            "StageDataManager: Loaded chapter %s (unlocked: %s)"
            % [chapter.chapter_name, chapter.is_unlocked]
          )
        )
    else:
      push_error("Failed to load stage data from %s" % STAGE_DATA_PATH)
  else:
    stage_select_data = StageSelectData.new()
    save_stage_data()
  print_debug("StageDataManager: Loaded stage data from %s" % STAGE_DATA_PATH)
  stage_data_loaded.emit()


func save_stage_data() -> void:
  if stage_select_data:
    ResourceSaver.save(stage_select_data, STAGE_DATA_PATH)


func get_chapter_by_id(chapter_id: String) -> ChapterData:
  if stage_select_data:
    return stage_select_data.get_chapter_by_id(chapter_id)
  return null


func get_stage_by_ids(chapter_id: String, stage_id: String) -> StageData:
  if stage_select_data:
    return stage_select_data.get_stage_by_ids(chapter_id, stage_id)
  return null


func unlock_stage(chapter_id: String, stage_id: String) -> bool:
  if stage_select_data and stage_select_data.unlock_stage(chapter_id, stage_id):
    save_stage_data()
    stage_unlocked.emit(chapter_id, stage_id)
    return true
  return false


func unlock_chapter(chapter_id: String) -> bool:
  if stage_select_data and stage_select_data.unlock_chapter(chapter_id):
    save_stage_data()
    chapter_unlocked.emit(chapter_id)
    return true
  return false


func start_stage(stage_data: StageData) -> void:
  if not stage_data or not stage_data.can_start():
    push_error("Cannot start stage: stage is locked or invalid")
    return
  var seed = stage_data.get_seed_for_play()
  RandomSeedGenerator.set_current_seed(seed)
  print("StageDataManager: Starting stage %s with seed: %s" % [stage_data.stage_name, seed])
  GameFlow.start_stage()


func get_all_chapters() -> Array[ChapterData]:
  if stage_select_data:
    return stage_select_data.chapters
  return []


func get_unlocked_chapters() -> Array[ChapterData]:
  if stage_select_data:
    return stage_select_data.get_unlocked_chapters()
  return []
