# === ステージクリア時のエンディング分岐テスト ===
extends GdUnitTestSuite


class StubUIController:
  extends StageUIController
  var ending_shown := false
  var clear_prompt_shown := false

  func show_ending() -> void:
    ending_shown = true  # ending_finished は emit しない（リザルト画面へ遷移させない）

  func handle_stage_cleared() -> void:
    clear_prompt_shown = true


class StubRegistry:
  extends StageComponentRegistry
  var components := {}

  func get_component(component_name: String) -> Node:
    return components.get(component_name)


class TestableStageManager:
  extends StageManager

  func _ready() -> void:
    pass  # ステージ初期化を走らせない


var _stage_manager: StageManager
var _ui: StubUIController
var _stage: StageData
var _orig_progress: Dictionary
var _orig_current_stage: StageData


func before_test() -> void:
  _orig_progress = StageDataManager.get_progress_dict()
  _orig_current_stage = StageDataManager.current_stage
  StageDataManager.apply_progress_dict({})

  _stage = StageData.new()
  _stage.chapter_id = "chapter_test"
  _stage.stage_id = "stage_test"
  _stage.has_ending = true
  StageDataManager.current_stage = _stage

  _ui = auto_free(StubUIController.new())
  var registry := StubRegistry.new()
  registry.components = {"ui": _ui}
  _stage_manager = auto_free(TestableStageManager.new())
  _stage_manager._component_registry = registry
  add_child(_stage_manager)


func after_test() -> void:
  StageDataManager.apply_progress_dict(_orig_progress)
  StageDataManager.current_stage = _orig_current_stage


func test_uncleared_ending_stage_shows_ending_instead_of_clear_prompt() -> void:
  # クリア処理の中でステージがクリア済みになっても、エンディングが選ばれること
  _stage_manager._on_stage_cleared()

  assert_bool(_ui.ending_shown).is_true()
  assert_bool(_ui.clear_prompt_shown).is_false()
