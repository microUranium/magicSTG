# === ステージ選択ボタンの表示テスト ===
extends GdUnitTestSuite

const StageButtonScene := preload("res://scenes/ui/select_stage_container.tscn")

var _stage: StageData
var _orig_stage_select_data: StageSelectData
var _orig_progress: Dictionary


func before_test() -> void:
  _orig_stage_select_data = StageDataManager.stage_select_data
  _orig_progress = StageDataManager.get_progress_dict()

  _stage = StageData.new()
  _stage.stage_name = "TEST"
  _stage.chapter_id = "c1"
  _stage.stage_id = "s1"
  var chapter := ChapterData.new()
  chapter.chapter_id = "c1"
  chapter.is_unlocked = true
  chapter.stages.assign([_stage])
  var data := StageSelectData.new()
  data.chapters.assign([chapter])
  StageDataManager.stage_select_data = data
  StageDataManager.apply_progress_dict({})


func after_test() -> void:
  StageDataManager.stage_select_data = _orig_stage_select_data
  StageDataManager.apply_progress_dict(_orig_progress)


func _make_button(unlocked: bool, cleared: bool = false) -> Control:
  _stage.is_unlocked = unlocked
  StageDataManager.set_stage_cleared("c1", "s1", cleared)

  var button: Control = auto_free(StageButtonScene.instantiate())
  button.setup_stage_data(_stage, Vector2.RIGHT)
  add_child(button)
  await await_idle_frame()
  return button


func test_unlocked_stage_button_is_visible() -> void:
  var button := await _make_button(true)

  assert_bool(button.visible).is_true()


func test_locked_stage_button_is_hidden() -> void:
  var button := await _make_button(false)

  assert_bool(button.visible).is_false()


func test_button_appears_when_stage_unlocked() -> void:
  var button := await _make_button(false)

  button.stage_data.is_unlocked = true
  button.update_display()

  assert_bool(button.visible).is_true()


func test_cleared_stage_shows_mark_and_dialogue_toggle() -> void:
  var button := await _make_button(true, true)

  assert_bool(button.cleared_mark.visible).is_true()
  assert_bool(button.dialogue_toggle.visible).is_true()


func test_uncleared_stage_hides_mark_and_dialogue_toggle() -> void:
  var button := await _make_button(true, false)

  assert_bool(button.cleared_mark.visible).is_false()
  assert_bool(button.dialogue_toggle.visible).is_false()


func test_cleared_mark_is_tilted_12_degrees() -> void:
  var button := await _make_button(true, true)

  assert_float(absf(button.cleared_mark.rotation_degrees)).is_equal_approx(12.0, 0.01)


func test_mark_and_toggle_follow_clear_state_change() -> void:
  var button := await _make_button(true, false)

  StageDataManager.set_stage_cleared("c1", "s1", true)
  button.update_display()

  assert_bool(button.cleared_mark.visible).is_true()
  assert_bool(button.dialogue_toggle.visible).is_true()


func test_dialogue_toggle_switches_dialogue_setting() -> void:
  var button := await _make_button(true, true)
  _stage.dialogue_enabled = true
  button.dialogue_enabled = true

  button.dialogue_toggle.pressed.emit()

  assert_bool(_stage.dialogue_enabled).is_false()
