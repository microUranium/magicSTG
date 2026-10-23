# === ステージ選択ボタンの表示テスト ===
extends GdUnitTestSuite

const StageButtonScene := preload("res://scenes/ui/select_stage_container.tscn")


func _make_button(unlocked: bool) -> Control:
  var stage := StageData.new()
  stage.stage_name = "TEST"
  stage.is_unlocked = unlocked

  var button: Control = auto_free(StageButtonScene.instantiate())
  button.setup_stage_data(stage, Vector2.RIGHT)
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
