# === 5-2「屋敷脱出」/ 6-2「魔族追跡」（ランダムシードステージ）のテスト ===
extends GdUnitTestSuite

const STAGE_SELECT_DATA_PATH := "res://resources/data/stage_select_data.tres"
const STAGE_DATA_PATH := "res://resources/data/stage_data.json"
const WAVE_COUNT := 10

var _templates: Dictionary
var _enemies: Dictionary


func before() -> void:
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA_PATH))
  _templates = data["wave_templates"]
  _enemies = data["enemies"]


func after_test() -> void:
  RandomSeedGenerator.clear_seed()


func _chapter(chapter_id: String) -> ChapterData:
  var select_data: StageSelectData = load(STAGE_SELECT_DATA_PATH)
  return select_data.get_chapter_by_id(chapter_id)


func _template_enemies(template_id: String) -> Array:
  return _templates[template_id]["layers"].map(func(layer): return layer["enemy"])


func _resolve_stage_number(seed_value: String) -> int:
  # StageManager._determine_current_stage() と同じく "s6"〜"s2" を大きい順に探す
  for n in [6, 5, 4, 3, 2]:
    if seed_value.contains("s%d" % n):
      return n
  return 1


# --- 5-2 屋敷脱出 ---


func test_stage5_2_is_second_stage_of_chapter5() -> void:
  var stages := _chapter("chapter5").stages

  assert_int(stages.size()).is_equal(3)
  var stage: StageData = stages[1]
  assert_str(stage.stage_id).is_equal("stage5_2")
  assert_str(stage.stage_name).is_equal("5-2 屋敷脱出")
  assert_bool(stage.is_seed_fixed).is_false()
  assert_bool(stage.dialogue_enabled).is_false()
  assert_array(stage.random_seed_pools).is_equal(
    [{"count": WAVE_COUNT, "pool": "stage5"}, {"count": 1, "pool": "stage5_boss"}]
  )


func test_stage5_boss_pool_is_bear_without_dialogue() -> void:
  var boss_templates := _templates.keys().filter(
    func(id): return _templates[id].get("pool", "") == "stage5_boss"
  )

  assert_array(boss_templates).is_not_empty()
  for id in boss_templates:
    assert_array(_template_enemies(id)).is_equal(["boss_bear_skip_dialogue"])
  var bear: Dictionary = _enemies["boss_bear_skip_dialogue"]
  assert_str(bear["scene_path"]).is_equal(_enemies["boss_bear"]["scene_path"])
  assert_str(bear["parameters"]["skip_dialogue"]).is_equal("true")


func test_stage5_2_seed_ends_with_bear_after_random_waves() -> void:
  var stage: StageData = _chapter("chapter5").stages[1]

  var parts := RandomSeedGenerator.generate_seed_with_pools(stage.random_seed_pools).split("-")

  assert_int(parts.size()).is_equal(WAVE_COUNT + 1)
  for i in WAVE_COUNT:
    # セリフパートなし: 会話・カットシーンは入らず、雑魚プールのウェーブだけ
    assert_str(_templates[parts[i]].get("pool", "")).is_equal("stage5")
  assert_array(_template_enemies(parts[WAVE_COUNT])).is_equal(["boss_bear_skip_dialogue"])
  assert_int(_resolve_stage_number("-".join(parts))).is_equal(5)


# --- 6-2 魔族追跡 ---


func test_stage6_2_is_second_stage_of_chapter6() -> void:
  var stages := _chapter("chapter6").stages

  assert_int(stages.size()).is_equal(3)
  var stage: StageData = stages[1]
  assert_str(stage.stage_id).is_equal("stage6_2")
  assert_str(stage.stage_name).is_equal("6-2 魔族追跡")
  assert_bool(stage.is_seed_fixed).is_false()
  assert_bool(stage.dialogue_enabled).is_false()
  # ボス出現なし: 雑魚プールのみ
  assert_array(stage.random_seed_pools).is_equal([{"count": WAVE_COUNT, "pool": "stage6"}])


func test_stage6_2_seed_has_only_random_waves_without_boss() -> void:
  var stage: StageData = _chapter("chapter6").stages[1]

  var parts := RandomSeedGenerator.generate_seed_with_pools(stage.random_seed_pools).split("-")

  assert_int(parts.size()).is_equal(WAVE_COUNT)
  for part in parts:
    assert_str(_templates[part].get("pool", "")).is_equal("stage6")
    for enemy in _template_enemies(part):
      assert_str(enemy).not_contains("boss")
  assert_int(_resolve_stage_number("-".join(parts))).is_equal(6)
