class_name StageProgressTest
extends GdUnitTestSuite

var _data: StageSelectData
var _orig_stage_select_data: StageSelectData
var _orig_progress: Dictionary
var _orig_current_stage: StageData


func before_test() -> void:
  _orig_stage_select_data = StageDataManager.stage_select_data
  _orig_progress = StageDataManager.get_progress_dict()
  _orig_current_stage = StageDataManager.current_stage

  _data = _build_stage_select_data()
  StageDataManager.stage_select_data = _data
  StageDataManager.apply_progress_dict({})
  StageDataManager.current_stage = null


func after_test() -> void:
  StageDataManager.stage_select_data = _orig_stage_select_data
  StageDataManager.apply_progress_dict(_orig_progress)
  StageDataManager.current_stage = _orig_current_stage


# ───────────────────────────────────
# StageSelectData.get_next_stage
# ───────────────────────────────────
func test_next_stage_within_chapter() -> void:
  assert_str(_data.get_next_stage("c1", "s1_1").stage_id).is_equal("s1_2")


func test_next_stage_moves_to_next_chapter_skipping_debug_chapter() -> void:
  assert_str(_data.get_next_stage("c1", "s1_2").stage_id).is_equal("s2_1")


func test_next_stage_is_null_for_last_stage() -> void:
  assert_object(_data.get_next_stage("c2", "s2_1")).is_null()


func test_next_stage_is_null_for_unknown_stage() -> void:
  assert_object(_data.get_next_stage("c1", "unknown")).is_null()
  assert_object(_data.get_next_stage("unknown", "s1_1")).is_null()


# ───────────────────────────────────
# StageDataManager の進行状況
# ───────────────────────────────────
func test_mark_cleared_records_clear_and_unlocks_next_stage() -> void:
  StageDataManager.current_stage = StageDataManager.get_stage_by_ids("c1", "s1_1")

  StageDataManager.mark_current_stage_cleared()

  assert_bool(StageDataManager.is_stage_cleared("c1", "s1_1")).is_true()
  assert_bool(StageDataManager.get_stage_by_ids("c1", "s1_2").is_unlocked).is_true()
  assert_array(StageDataManager.get_progress_dict()["unlocked_stages"]).contains_exactly(
    ["c1/s1_2"]
  )


func test_mark_cleared_unlocks_next_chapter() -> void:
  StageDataManager.current_stage = StageDataManager.get_stage_by_ids("c1", "s1_2")

  StageDataManager.mark_current_stage_cleared()

  assert_bool(StageDataManager.get_chapter_by_id("c2").is_unlocked).is_true()
  assert_bool(StageDataManager.get_stage_by_ids("c2", "s2_1").is_unlocked).is_true()
  assert_bool(StageDataManager.get_chapter_by_id("debug").is_unlocked).is_false()
  assert_array(StageDataManager.get_progress_dict()["unlocked_chapters"]).contains_exactly(["c2"])


func test_mark_cleared_does_nothing_without_current_stage() -> void:
  StageDataManager.mark_current_stage_cleared()

  var progress := StageDataManager.get_progress_dict()
  assert_array(progress["cleared_stages"]).is_empty()
  assert_array(progress["unlocked_stages"]).is_empty()


func test_finish_stage_clears_current_stage() -> void:
  StageDataManager.current_stage = StageDataManager.get_stage_by_ids("c1", "s1_1")

  StageDataManager.finish_stage()

  assert_object(StageDataManager.current_stage).is_null()


func test_apply_progress_dict_unlocks_and_restores_clears() -> void:
  StageDataManager.apply_progress_dict(
    {
      "unlocked_chapters": ["c2"],
      "unlocked_stages": ["c1/s1_2", "c2/s2_1"],
      "cleared_stages": ["c1/s1_1"]
    }
  )

  assert_bool(StageDataManager.get_chapter_by_id("c2").is_unlocked).is_true()
  assert_bool(StageDataManager.get_stage_by_ids("c1", "s1_2").is_unlocked).is_true()
  assert_bool(StageDataManager.get_stage_by_ids("c2", "s2_1").is_unlocked).is_true()
  assert_bool(StageDataManager.is_stage_cleared("c1", "s1_1")).is_true()


func test_apply_progress_dict_ignores_unknown_ids() -> void:
  StageDataManager.apply_progress_dict(
    {"unlocked_chapters": ["missing"], "unlocked_stages": ["c1/missing", "malformed"]}
  )

  var progress := StageDataManager.get_progress_dict()
  assert_array(progress["unlocked_chapters"]).is_empty()
  assert_array(progress["unlocked_stages"]).is_empty()


# ───────────────────────────────────
# 進行状況の直接編集（デバッグ用）
# ───────────────────────────────────
func test_capture_initial_state_keeps_first_snapshot() -> void:
  _data.unlock_stage("c1", "s1_2")
  _data.capture_initial_state()  # 2回目の呼び出しは無視される

  _data.restore_initial_state()

  assert_bool(_data.get_stage_by_ids("c1", "s1_2").is_unlocked).is_false()


func test_reset_progress_restores_definition_state() -> void:
  StageDataManager.current_stage = StageDataManager.get_stage_by_ids("c1", "s1_2")
  StageDataManager.mark_current_stage_cleared()

  StageDataManager.reset_progress()

  assert_bool(StageDataManager.get_chapter_by_id("c2").is_unlocked).is_false()
  assert_bool(StageDataManager.get_stage_by_ids("c2", "s2_1").is_unlocked).is_false()
  assert_bool(StageDataManager.is_stage_cleared("c1", "s1_2")).is_false()
  assert_bool(StageDataManager.get_stage_by_ids("c1", "s1_1").is_unlocked).is_true()


func test_set_stage_unlocked_unlocks_and_locks() -> void:
  StageDataManager.set_stage_unlocked("c1", "s1_2", true)
  assert_bool(StageDataManager.get_stage_by_ids("c1", "s1_2").is_unlocked).is_true()
  assert_array(StageDataManager.get_progress_dict()["unlocked_stages"]).contains_exactly(
    ["c1/s1_2"]
  )

  StageDataManager.set_stage_unlocked("c1", "s1_2", false)
  assert_bool(StageDataManager.get_stage_by_ids("c1", "s1_2").is_unlocked).is_false()
  assert_array(StageDataManager.get_progress_dict()["unlocked_stages"]).is_empty()


func test_set_chapter_unlocked_unlocks_and_locks() -> void:
  StageDataManager.set_chapter_unlocked("c2", true)
  assert_bool(StageDataManager.get_chapter_by_id("c2").is_unlocked).is_true()
  assert_array(StageDataManager.get_progress_dict()["unlocked_chapters"]).contains_exactly(["c2"])

  StageDataManager.set_chapter_unlocked("c2", false)
  assert_bool(StageDataManager.get_chapter_by_id("c2").is_unlocked).is_false()
  assert_array(StageDataManager.get_progress_dict()["unlocked_chapters"]).is_empty()


func test_set_stage_cleared_toggles_clear() -> void:
  StageDataManager.set_stage_cleared("c1", "s1_1", true)
  assert_bool(StageDataManager.is_stage_cleared("c1", "s1_1")).is_true()

  StageDataManager.set_stage_cleared("c1", "s1_1", false)
  assert_bool(StageDataManager.is_stage_cleared("c1", "s1_1")).is_false()


func test_set_stage_cleared_ignores_unknown_stage() -> void:
  StageDataManager.set_stage_cleared("c1", "missing", true)

  assert_array(StageDataManager.get_progress_dict()["cleared_stages"]).is_empty()


func test_unlock_all_unlocks_every_chapter_and_stage() -> void:
  StageDataManager.unlock_all()

  for chapter in _data.chapters:
    assert_bool(chapter.is_unlocked).is_true()
    for stage in chapter.stages:
      assert_bool(stage.is_unlocked).is_true()
  assert_array(StageDataManager.get_progress_dict()["cleared_stages"]).is_empty()


func test_unlock_all_with_clear_marks_every_stage_cleared() -> void:
  StageDataManager.unlock_all(true)

  (
    assert_array(StageDataManager.get_progress_dict()["cleared_stages"])
    . contains_exactly_in_any_order(["c1/s1_1", "c1/s1_2", "debug/d1", "c2/s2_1"])
  )


func test_progress_changed_emitted_on_edit() -> void:
  var emitter := monitor_signals(StageDataManager, false)

  StageDataManager.set_stage_cleared("c1", "s1_1", true)

  await assert_signal(emitter).wait_until(50).is_emitted("progress_changed")


# ───────────────────────────────────
# Helpers
# ───────────────────────────────────
func _build_stage_select_data() -> StageSelectData:
  var c1 := _make_chapter(
    "c1", true, [_make_stage("c1", "s1_1", true), _make_stage("c1", "s1_2", false)]
  )
  var debug := _make_chapter("debug", false, [_make_stage("debug", "d1", false)])
  debug.is_debug_only = true
  var c2 := _make_chapter("c2", false, [_make_stage("c2", "s2_1", false)])

  var data := StageSelectData.new()
  data.chapters.assign([c1, debug, c2])
  return data


func _make_chapter(chapter_id: String, unlocked: bool, stages: Array) -> ChapterData:
  var chapter := ChapterData.new()
  chapter.chapter_id = chapter_id
  chapter.is_unlocked = unlocked
  chapter.stages.assign(stages)
  return chapter


func _make_stage(chapter_id: String, stage_id: String, unlocked: bool) -> StageData:
  var stage := StageData.new()
  stage.chapter_id = chapter_id
  stage.stage_id = stage_id
  stage.is_unlocked = unlocked
  return stage
