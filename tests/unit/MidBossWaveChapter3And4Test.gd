# === 第3章・第4章の中ボスのテスト ===
# x-2: ランダムシードに演出スキップの中ボスが含まれる
# x-3: 固定シードに演出スキップ・BGM 不変・撃破エフェクトなしの中ボスが含まれる
# 中ボスの出現位置は調整しうるため、位置は確認しない
extends GdUnitTestSuite

const STAGE_SELECT_DATA_PATH := "res://resources/data/stage_select_data.tres"
const STAGE_DATA_PATH := "res://resources/data/stage_data.json"
const SKIP_DIALOGUE_ONLY := {"skip_dialogue": "true"}
const SKIP_ALL_EFFECTS := {
  "skip_dialogue": "true", "skip_bgm_change": "true", "skip_boss_defeat_effect": "true"
}

# chapter -> 中ボス（元の敵 ID）
const MID_BOSSES := {3: "boss_robe", 4: "boss_spider"}

var _templates: Dictionary
var _enemies: Dictionary


func before() -> void:
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA_PATH))
  _templates = data["wave_templates"]
  _enemies = data["enemies"]


func after_test() -> void:
  RandomSeedGenerator.clear_seed()


func _stage(chapter: int, number: int) -> StageData:
  var select_data: StageSelectData = load(STAGE_SELECT_DATA_PATH)
  return select_data.get_stage_by_ids("chapter%d" % chapter, "stage%d_%d" % [chapter, number])


func _is_variant_of(enemy_id: String, boss_id: String, parameters: Dictionary) -> bool:
  var enemy: Dictionary = _enemies.get(enemy_id, {})
  return (
    enemy.get("scene_path", "") == _enemies[boss_id]["scene_path"]
    and enemy.get("parameters", {}) == parameters
  )


func _count_mid_boss_waves(seed_value: String, boss_id: String, parameters: Dictionary) -> int:
  var count := 0
  for part in seed_value.split("-"):
    if not _templates.has(part):
      continue  # 会話・カットシーン
    for layer in _templates[part]["layers"]:
      if _is_variant_of(layer["enemy"], boss_id, parameters):
        count += 1
  return count


func test_second_stage_seed_contains_mid_boss_skipping_dialogue() -> void:
  for chapter in MID_BOSSES:
    var stage := _stage(chapter, 2)
    assert_bool(stage.is_seed_fixed).is_false()

    var seed_value := RandomSeedGenerator.generate_seed_with_pools(stage.random_seed_pools)
    var count := _count_mid_boss_waves(seed_value, MID_BOSSES[chapter], SKIP_DIALOGUE_ONLY)

    assert_int(count).override_failure_message("stage%d_2: %s" % [chapter, seed_value]).is_equal(1)


func test_third_stage_seed_contains_mid_boss_without_effects() -> void:
  for chapter in MID_BOSSES:
    var seed_value := _stage(chapter, 3).fixed_seed
    var count := _count_mid_boss_waves(seed_value, MID_BOSSES[chapter], SKIP_ALL_EFFECTS)

    assert_int(count).override_failure_message("stage%d_3: %s" % [chapter, seed_value]).is_equal(1)
