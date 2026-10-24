extends Resource
class_name StageSelectData

@export var chapters: Array[ChapterData] = []

# 定義上の初期解放状態（ChapterData / StageData → bool）。進行状況のリセットに使う
var _initial_unlocked := {}
var _initial_captured := false


## 現在の解放状態を初期状態として記録する。2回目以降の呼び出しでは何もしない。
func capture_initial_state() -> void:
  if _initial_captured:
    return
  _initial_captured = true
  for chapter in chapters:
    _initial_unlocked[chapter] = chapter.is_unlocked
    for stage in chapter.stages:
      _initial_unlocked[stage] = stage.is_unlocked


## 解放状態を capture_initial_state() で記録した状態に戻す。
func restore_initial_state() -> void:
  for res in _initial_unlocked:
    res.is_unlocked = _initial_unlocked[res]


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


func get_unlocked_chapters(include_debug: bool = OS.is_debug_build()) -> Array[ChapterData]:
  var unlocked: Array[ChapterData] = []
  for chapter in chapters:
    if chapter.is_debug_only and not include_debug:
      continue
    if chapter.is_unlocked:
      unlocked.append(chapter)
  return unlocked


## 指定ステージの次のステージを返す（無ければ null）。
## チャプター内の最後のステージであれば、次のチャプター（デバッグ専用は除く）の最初のステージを返す。
func get_next_stage(chapter_id: String, stage_id: String) -> StageData:
  var chapter_index := -1
  for i in chapters.size():
    if chapters[i].chapter_id == chapter_id:
      chapter_index = i
      break
  if chapter_index < 0:
    return null

  var stages: Array[StageData] = chapters[chapter_index].stages
  var stage_index := -1
  for i in stages.size():
    if stages[i].stage_id == stage_id:
      stage_index = i
      break
  if stage_index < 0:
    return null
  if stage_index + 1 < stages.size():
    return stages[stage_index + 1]

  for i in range(chapter_index + 1, chapters.size()):
    var chapter := chapters[i]
    if chapter.is_debug_only or chapter.stages.is_empty():
      continue
    return chapter.stages[0]
  return null


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
