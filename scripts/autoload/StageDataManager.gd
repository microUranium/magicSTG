extends Node

signal stage_data_loaded
signal stage_unlocked(chapter_id: String, stage_id: String)
signal chapter_unlocked(chapter_id: String)
signal stage_cleared(chapter_id: String, stage_id: String)
signal progress_changed  # 解放・クリア状態が変化した（UI の再描画用）

## ステージ構成の定義データ。読み取り専用とし、進行状況はセーブデータ（SaveManager）側で保持する。
const STAGE_DATA_PATH = "res://resources/data/stage_select_data.tres"
var stage_select_data: StageSelectData:
  set(value):
    stage_select_data = value
    if value:
      value.capture_initial_state()  # リセット用に定義上の解放状態を記録しておく

## 現在プレイ中のステージ（ステージ選択から開始した場合のみ設定される）
var current_stage: StageData = null

# 進行によって解放・クリアされたもの（キー → true）
# ステージのキーは "chapter_id/stage_id"、チャプターのキーは chapter_id
var _unlocked_chapters := {}
var _unlocked_stages := {}
var _cleared_stages := {}


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
    push_error("Stage data not found: %s" % STAGE_DATA_PATH)
    stage_select_data = StageSelectData.new()
  print_debug("StageDataManager: Loaded stage data from %s" % STAGE_DATA_PATH)
  stage_data_loaded.emit()


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
    _unlocked_stages[_stage_key(chapter_id, stage_id)] = true
    stage_unlocked.emit(chapter_id, stage_id)
    return true
  return false


func unlock_chapter(chapter_id: String) -> bool:
  if stage_select_data and stage_select_data.unlock_chapter(chapter_id):
    _unlocked_chapters[chapter_id] = true
    chapter_unlocked.emit(chapter_id)
    return true
  return false


func start_stage(stage_data: StageData) -> void:
  if not stage_data or not stage_data.can_start():
    push_error("Cannot start stage: stage is locked or invalid")
    return
  current_stage = stage_data
  var seed = stage_data.get_seed_for_play()
  RandomSeedGenerator.set_current_seed(seed)
  print("StageDataManager: Starting stage %s with seed: %s" % [stage_data.stage_name, seed])
  GameFlow.start_stage()


## プレイ中のステージをクリア済みにし、次のステージ（必要ならチャプターも）を解放する。
## メモリ上の更新のみで、ファイルへの保存はリザルト画面退出時に SaveManager が行う。
func mark_current_stage_cleared() -> void:
  if current_stage == null:
    return

  var chapter_id := current_stage.chapter_id
  var stage_id := current_stage.stage_id
  _cleared_stages[_stage_key(chapter_id, stage_id)] = true
  stage_cleared.emit(chapter_id, stage_id)

  var next: StageData = stage_select_data.get_next_stage(chapter_id, stage_id)
  if next == null:
    return
  var next_chapter := get_chapter_by_id(next.chapter_id)
  if next_chapter and not next_chapter.is_unlocked:
    unlock_chapter(next.chapter_id)
  if not next.is_unlocked:
    unlock_stage(next.chapter_id, next.stage_id)
  progress_changed.emit()


## ステージのプレイを終える（リザルト画面退出時に呼ぶ）。
func finish_stage() -> void:
  current_stage = null


func is_stage_cleared(chapter_id: String, stage_id: String) -> bool:
  return _cleared_stages.has(_stage_key(chapter_id, stage_id))


func get_all_chapters() -> Array[ChapterData]:
  if stage_select_data:
    return stage_select_data.chapters
  return []


func get_unlocked_chapters() -> Array[ChapterData]:
  if stage_select_data:
    return stage_select_data.get_unlocked_chapters()
  return []


# ───────────── セーブデータ変換 ───────────────
func get_progress_dict() -> Dictionary:
  return {
    "unlocked_chapters": _unlocked_chapters.keys(),
    "unlocked_stages": _unlocked_stages.keys(),
    "cleared_stages": _cleared_stages.keys()
  }


## セーブデータの進行状況を反映する。
## 解放状態をいったん定義データの初期状態に戻してから、進行による解放・クリアを重ねる。
func apply_progress_dict(progress: Dictionary) -> void:
  _unlocked_chapters.clear()
  _unlocked_stages.clear()
  _cleared_stages.clear()
  if stage_select_data:
    stage_select_data.restore_initial_state()

  for chapter_id in progress.get("unlocked_chapters", []):
    if not unlock_chapter(chapter_id):
      push_warning("Unknown chapter '%s' in save data." % chapter_id)

  for key in progress.get("unlocked_stages", []):
    var ids: PackedStringArray = str(key).split("/")
    if ids.size() != 2 or not unlock_stage(ids[0], ids[1]):
      push_warning("Unknown stage '%s' in save data." % key)

  for key in progress.get("cleared_stages", []):
    _cleared_stages[str(key)] = true
  progress_changed.emit()


# ───────────── 進行状況の直接編集（デバッグ用） ───────────────
## 進行状況を初期状態（定義データどおり、クリアなし）に戻す。
func reset_progress() -> void:
  apply_progress_dict({})


## チャプターの解放状態を設定する。
## 定義上で初期解放されているものをロックした場合、次回ロード時には解放に戻る。
func set_chapter_unlocked(chapter_id: String, unlocked: bool) -> void:
  var chapter := get_chapter_by_id(chapter_id)
  if chapter == null or chapter.is_unlocked == unlocked:
    return
  if unlocked:
    unlock_chapter(chapter_id)
  else:
    chapter.is_unlocked = false
    _unlocked_chapters.erase(chapter_id)
  progress_changed.emit()


## ステージの解放状態を設定する。
## 定義上で初期解放されているものをロックした場合、次回ロード時には解放に戻る。
func set_stage_unlocked(chapter_id: String, stage_id: String, unlocked: bool) -> void:
  var stage := get_stage_by_ids(chapter_id, stage_id)
  if stage == null or stage.is_unlocked == unlocked:
    return
  if unlocked:
    unlock_stage(chapter_id, stage_id)
  else:
    stage.is_unlocked = false
    _unlocked_stages.erase(_stage_key(chapter_id, stage_id))
  progress_changed.emit()


func set_stage_cleared(chapter_id: String, stage_id: String, cleared: bool) -> void:
  if get_stage_by_ids(chapter_id, stage_id) == null:
    return
  var key := _stage_key(chapter_id, stage_id)
  if cleared:
    _cleared_stages[key] = true
  else:
    _cleared_stages.erase(key)
  progress_changed.emit()


## すべてのチャプター・ステージを解放する。clear が true ならすべてクリア済みにもする。
func unlock_all(clear: bool = false) -> void:
  for chapter in get_all_chapters():
    if not chapter.is_unlocked:
      unlock_chapter(chapter.chapter_id)
    for stage in chapter.stages:
      if not stage.is_unlocked:
        unlock_stage(chapter.chapter_id, stage.stage_id)
      if clear:
        _cleared_stages[_stage_key(chapter.chapter_id, stage.stage_id)] = true
  progress_changed.emit()


static func _stage_key(chapter_id: String, stage_id: String) -> String:
  return "%s/%s" % [chapter_id, stage_id]
