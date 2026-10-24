# === ステージ進行状況デバッグパネルのテスト ===
extends GdUnitTestSuite

const StageProgressDebugPanel := preload("res://scripts/ui/StageProgressDebugPanel.gd")
const TEST_SAVE_PATH := "user://test_stage_progress_debug_panel.json"

var _panel: PanelContainer
var _orig_save_path: String
var _orig_stage_select_data: StageSelectData
var _orig_progress: Dictionary


func before_test() -> void:
  _orig_save_path = SaveManager.save_path
  _orig_stage_select_data = StageDataManager.stage_select_data
  _orig_progress = StageDataManager.get_progress_dict()

  SaveManager.save_path = TEST_SAVE_PATH
  _remove_test_save()
  StageDataManager.stage_select_data = _build_stage_select_data()
  StageDataManager.apply_progress_dict({})

  _panel = auto_free(StageProgressDebugPanel.new())
  add_child(_panel)


func after_test() -> void:
  _remove_test_save()
  SaveManager.save_path = _orig_save_path
  StageDataManager.stage_select_data = _orig_stage_select_data
  StageDataManager.apply_progress_dict(_orig_progress)


func test_builds_checkboxes_for_each_chapter_and_stage() -> void:
  assert_int(_panel._chapter_checks.size()).is_equal(2)
  assert_int(_panel._stage_unlock_checks.size()).is_equal(3)
  assert_int(_panel._stage_clear_checks.size()).is_equal(3)


func test_checkboxes_reflect_current_progress() -> void:
  assert_bool(_panel._chapter_checks["c1"].button_pressed).is_true()
  assert_bool(_panel._chapter_checks["c2"].button_pressed).is_false()
  assert_bool(_panel._stage_unlock_checks["c1/s1_1"].button_pressed).is_true()
  assert_bool(_panel._stage_unlock_checks["c1/s1_2"].button_pressed).is_false()
  assert_bool(_panel._stage_clear_checks["c1/s1_1"].button_pressed).is_false()


func test_toggling_checkbox_updates_progress_and_saves() -> void:
  _panel._stage_unlock_checks["c1/s1_2"].button_pressed = true
  _panel._stage_clear_checks["c1/s1_1"].button_pressed = true

  assert_bool(StageDataManager.get_stage_by_ids("c1", "s1_2").is_unlocked).is_true()
  assert_bool(StageDataManager.is_stage_cleared("c1", "s1_1")).is_true()
  assert_bool(FileAccess.file_exists(TEST_SAVE_PATH)).is_true()


func test_checkboxes_follow_external_progress_change() -> void:
  StageDataManager.unlock_all(true)

  assert_bool(_panel._chapter_checks["c2"].button_pressed).is_true()
  assert_bool(_panel._stage_unlock_checks["c2/s2_1"].button_pressed).is_true()
  assert_bool(_panel._stage_clear_checks["c2/s2_1"].button_pressed).is_true()

  StageDataManager.reset_progress()

  assert_bool(_panel._chapter_checks["c2"].button_pressed).is_false()
  assert_bool(_panel._stage_clear_checks["c2/s2_1"].button_pressed).is_false()


# ───────────────────────────────────
# Helpers
# ───────────────────────────────────
func _remove_test_save() -> void:
  if FileAccess.file_exists(TEST_SAVE_PATH):
    DirAccess.remove_absolute(TEST_SAVE_PATH)


func _build_stage_select_data() -> StageSelectData:
  var c1 := ChapterData.new()
  c1.chapter_id = "c1"
  c1.is_unlocked = true
  c1.stages.assign([_make_stage("c1", "s1_1", true), _make_stage("c1", "s1_2", false)])
  var c2 := ChapterData.new()
  c2.chapter_id = "c2"
  c2.stages.assign([_make_stage("c2", "s2_1", false)])

  var data := StageSelectData.new()
  data.chapters.assign([c1, c2])
  return data


func _make_stage(chapter_id: String, stage_id: String, unlocked: bool) -> StageData:
  var stage := StageData.new()
  stage.chapter_id = chapter_id
  stage.stage_id = stage_id
  stage.is_unlocked = unlocked
  return stage
