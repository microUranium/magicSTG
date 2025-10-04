extends Resource
class_name StageSelectData

@export var chapters: Array[ChapterData] = []


func get_chapter_by_id(chapter_id: String) -> ChapterData:
  for chapter in chapters:
    if chapter.chapter_id == chapter_id:
      return chapter
  return null


func get_stage_by_ids(chapter_id: String, stage_id: String) -> StageData:
  var chapter = get_chapter_by_id(chapter_id)
  if chapter:
    return chapter.get_stage_by_id(stage_id)
  return null


func get_unlocked_chapters() -> Array[ChapterData]:
  var unlocked: Array[ChapterData] = []
  for chapter in chapters:
    if chapter.is_unlocked:
      unlocked.append(chapter)
  return unlocked


func unlock_stage(chapter_id: String, stage_id: String) -> bool:
  var stage = get_stage_by_ids(chapter_id, stage_id)
  if stage:
    stage.is_unlocked = true
    return true
  return false


func unlock_chapter(chapter_id: String) -> bool:
  var chapter = get_chapter_by_id(chapter_id)
  if chapter:
    chapter.is_unlocked = true
    return true
  return false
