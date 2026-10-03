# 演出イベント定義とシードの整合性テスト
extends GdUnitTestSuite

const STAGE_SELECT_DATA_PATH := "res://resources/data/stage_select_data.tres"


func test_all_cutscenes_reference_existing_resources() -> void:
  assert_dict(GameDataRegistry.cutscenes).is_not_empty()

  for cutscene_id in GameDataRegistry.cutscenes.keys():
    var steps: Array = GameDataRegistry.get_cutscene_data(cutscene_id).get("steps", [])
    assert_array(steps).is_not_empty()

    for step in steps:
      match step.get("type", ""):
        "dialogue":
          assert_array(GameDataRegistry.get_dialogue_data(step["path"])).is_not_empty()
        "set_background":
          assert_bool(ResourceLoader.exists(step["texture"])).is_true()
        "spawn_actor":
          assert_bool(ResourceLoader.exists(step["scene"])).is_true()
        "play_bgm":
          assert_bool(ResourceLoader.exists(step["path"])).is_true()


func test_fixed_seeds_reference_existing_cutscenes() -> void:
  var stage_select_data = load(STAGE_SELECT_DATA_PATH)
  assert_object(stage_select_data).is_not_null()

  var referenced: Array[String] = []
  for chapter in stage_select_data.chapters:
    for stage in chapter.stages:
      for part in stage.fixed_seed.split("-"):
        if not part.begins_with("C"):
          continue
        var cutscene_id: String = part.substr(1)
        referenced.append(cutscene_id)
        assert_dict(GameDataRegistry.get_cutscene_data(cutscene_id)).is_not_empty()

  # 4-3 と 5-3 の演出がシードから参照されていること
  assert_array(referenced).contains(["s2c1", "s4c1", "s5c1"])
