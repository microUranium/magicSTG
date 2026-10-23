# === 雑魚敵の強さ比較用デバッグステージのテスト ===
# 派生版と同ステージの既存敵を 1 体ずつ順番に出すデバッグ章が、データとして正しく組まれていることを確認する
extends GdUnitTestSuite

const STAGE_SELECT_DATA_PATH := "res://resources/data/stage_select_data.tres"
const STAGE_DATA_PATH := "res://resources/data/stage_data.json"
const DEBUG_CHAPTER_ID := "chapter_debug"

# stage_id -> 背景・BGM の判定に使われるステージ番号と、順番に出てくる敵
const EXPECTED_STAGES := {
  "debug_stage3":
  {
    "stage_number": 3,
    "enemies": ["enemy_lantern", "enemy_grimoire", "enemy_bat_a", "enemy_lantern_b_weak"],
  },
  "debug_stage5":
  {
    "stage_number": 5,
    "enemies":
    [
      "enemy_bat_b",
      "enemy_ghost",
      "enemy_lantern_b",
      "enemy_lantern_ch5",
      "enemy_grimoire_strong",
    ],
  },
  "debug_stage6":
  {
    "stage_number": 6,
    "enemies":
    [
      "enemy_bird_d",
      "enemy_flower_c",
      "enemy_flower_b_strong",
      "enemy_swamp_bird_ch6",
      "enemy_cedar",
    ],
  },
}


func _load_wave_templates() -> Dictionary:
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA_PATH))
  return data["wave_templates"]


func _debug_chapter() -> ChapterData:
  var stage_select_data: StageSelectData = load(STAGE_SELECT_DATA_PATH)
  return stage_select_data.get_chapter_by_id(DEBUG_CHAPTER_ID)


func test_debug_chapter_is_debug_only() -> void:
  var chapter := _debug_chapter()

  assert_object(chapter).is_not_null()
  assert_bool(chapter.is_debug_only).is_true()


func test_debug_chapter_hidden_without_debug_build() -> void:
  var stage_select_data: StageSelectData = load(STAGE_SELECT_DATA_PATH)

  var release_ids := stage_select_data.get_unlocked_chapters(false).map(
    func(c): return c.chapter_id
  )
  var debug_ids := stage_select_data.get_unlocked_chapters(true).map(func(c): return c.chapter_id)

  assert_array(release_ids).not_contains([DEBUG_CHAPTER_ID])
  assert_array(debug_ids).contains([DEBUG_CHAPTER_ID])
  # 通常の章はどちらでも表示される
  assert_int(debug_ids.size()).is_equal(release_ids.size() + 1)


func test_debug_stages_spawn_each_enemy_alone_in_order() -> void:
  var templates := _load_wave_templates()
  var chapter := _debug_chapter()

  assert_int(chapter.stages.size()).is_equal(EXPECTED_STAGES.size())
  for stage in chapter.stages:
    assert_bool(EXPECTED_STAGES.has(stage.stage_id)).is_true()
    assert_bool(stage.is_seed_fixed).is_true()

    var spawned := []
    for part in stage.fixed_seed.split("-"):
      # C / D で始まる ID はカットシーン・会話として解釈されてしまう
      assert_bool(part.begins_with("C") or part.begins_with("D")).is_false()
      (
        assert_bool(templates.has(part))
        . override_failure_message("missing template: " + part)
        . is_true()
      )

      var layers: Array = templates[part]["layers"]
      assert_int(layers.size()).is_equal(1)
      assert_int(int(layers[0]["count"])).is_equal(1)
      spawned.append(layers[0]["enemy"])

    assert_array(spawned).is_equal(EXPECTED_STAGES[stage.stage_id]["enemies"])


func test_debug_stage_seeds_resolve_to_their_stage_environment() -> void:
  # StageManager._determine_current_stage() はシード中の "s6"〜"s2" を大きい順に探して背景・BGM を決める
  for stage in _debug_chapter().stages:
    var expected: int = EXPECTED_STAGES[stage.stage_id]["stage_number"]
    var resolved := 1
    for n in [6, 5, 4, 3, 2]:
      if stage.fixed_seed.contains("s%d" % n):
        resolved = n
        break
    assert_int(resolved).is_equal(expected)


func test_debug_templates_are_not_in_random_pools() -> void:
  # デバッグ用テンプレートが通常のランダムステージで抽選されないこと
  var templates := _load_wave_templates()
  for template_id in templates:
    if template_id.substr(2, 2) == "x_":
      assert_bool(templates[template_id].has("pool")).is_false()
