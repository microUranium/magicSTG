# === stage3〜6 の雑魚ウェーブ構成テスト ===
# プールの拡充と、x-1 / x-3 専用ウェーブの方針がデータとして守られていることを確認する
extends GdUnitTestSuite

const STAGE_DATA_PATH := "res://resources/data/stage_data.json"
const STAGE_SELECT_DATA_PATH := "res://resources/data/stage_select_data.tres"
const MIN_POOL_TEMPLATES := 10
const MAX_FIRST_STAGE_DEDICATED_ENEMIES := 3

# docs/enemy_stage_matrix.md で決めた、各ステージに出現する雑魚敵
const STAGE_ENEMIES := {
  3: ["enemy_lantern", "enemy_grimoire", "enemy_bat_a", "enemy_lantern_b_weak"],
  4: ["enemy_swamp_bird", "enemy_living_wood", "enemy_spike", "enemy_piranha"],
  5:
  ["enemy_bat_b", "enemy_ghost", "enemy_lantern_b", "enemy_lantern_ch5", "enemy_grimoire_strong"],
  6:
  [
    "enemy_bird_d", "enemy_flower_c", "enemy_flower_b_strong", "enemy_swamp_bird_ch6", "enemy_cedar"
  ],
}

# 敵の AI に合う出現パターン
const FROM_TOP := ["from_top_spacing"]  # ForwardMoveAndStop: 上から下へ進んで止まる
const ALLOWED_PATTERNS := {
  "enemy_lantern": FROM_TOP,
  "enemy_lantern_ch5": FROM_TOP,  # 5 章のドロップ用派生版
  "enemy_lantern_b": FROM_TOP,
  "enemy_lantern_b_weak": FROM_TOP,
  "enemy_living_wood": FROM_TOP,
  "enemy_bat_b": FROM_TOP,
  "enemy_flower_c": FROM_TOP,
  "enemy_flower_b_strong": FROM_TOP,
  "enemy_cedar": FROM_TOP,
  # WarpBehind: 出現直後に自機の背後へワープする
  "enemy_grimoire": FROM_TOP,
  "enemy_grimoire_strong": FROM_TOP,
  # RushAttack: 出現時点の自機方向へ突進する
  "enemy_bat_a": ["perimeter_sequential"],
  "enemy_spike": ["single_random", "burst_same_pos"],
  # DistanceKeeping: 自機と距離を保つ
  "enemy_swamp_bird": ["single_random"],
  "enemy_swamp_bird_ch6": ["single_random"],  # 6 章のドロップ用派生版
  "enemy_ghost": ["single_random"],
  # LineHorizMove: 横一列に整列する
  "enemy_piranha": ["line_horiz"],
  # StraightMove: 自機へ寄りつつ画面上半分に留まる
  "enemy_bird_d": ["burst_same_pos"],
}
# 出現位置に留まらないため、from_top_spacing の位置重なりを気にしなくてよい敵
const LEAVES_SPAWN_POSITION := ["enemy_grimoire", "enemy_grimoire_strong"]

var _templates: Dictionary


func before() -> void:
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA_PATH))
  _templates = data["wave_templates"]


func _is_stage_template(template_id: String, stage: int) -> bool:
  # ボス（z）とデバッグ用（x_）は対象外
  return (
    template_id.begins_with("s%d" % stage)
    and not template_id.contains("z")
    and not template_id.contains("x_")
  )


func _stage_template_ids(stage: int) -> Array:
  return _templates.keys().filter(func(id): return _is_stage_template(id, stage))


func _pool_template_ids(stage: int) -> Array:
  return _stage_template_ids(stage).filter(func(id): return _templates[id].has("pool"))


func _enemy_count(template_id: String) -> int:
  var total := 0
  for layer in _templates[template_id]["layers"]:
    total += int(layer["count"])
  return total


func _waves_in_seed(seed_value: String) -> Array:
  return Array(seed_value.split("-")).filter(
    func(part): return not part.begins_with("C") and not part.begins_with("D")
  )


func _stage(chapter: int, number: int) -> StageData:
  var select_data: StageSelectData = load(STAGE_SELECT_DATA_PATH)
  return select_data.get_stage_by_ids("chapter%d" % chapter, "stage%d_%d" % [chapter, number])


func test_each_stage_has_enough_pool_templates() -> void:
  for stage in STAGE_ENEMIES:
    var ids := _pool_template_ids(stage)
    assert_int(ids.size()).override_failure_message("stage%d pool" % stage).is_greater_equal(
      MIN_POOL_TEMPLATES
    )
    for id in ids:
      assert_str(_templates[id]["pool"]).is_equal("stage%d" % stage)
      assert_int(int(_templates[id]["weight"])).is_greater(0)


func test_stage_templates_use_only_that_stages_enemies() -> void:
  for stage in STAGE_ENEMIES:
    var used := {}
    for id in _stage_template_ids(stage):
      for layer in _templates[id]["layers"]:
        (
          assert_array(STAGE_ENEMIES[stage])
          . override_failure_message("%s uses %s" % [id, layer["enemy"]])
          . contains([layer["enemy"]])
        )
        if _templates[id].has("pool"):
          used[layer["enemy"]] = true
    # 出現させると決めた敵は、すべてプールのどこかに出てくる
    assert_array(used.keys()).contains_exactly_in_any_order(STAGE_ENEMIES[stage])


func test_spawn_patterns_match_enemy_ai() -> void:
  for stage in STAGE_ENEMIES:
    for id in _templates:
      if not id.begins_with("s%d" % stage) or id.contains("z"):
        continue
      for layer in _templates[id]["layers"]:
        var enemy: String = layer["enemy"]
        assert_bool(ALLOWED_PATTERNS.has(enemy)).override_failure_message(enemy).is_true()
        (
          assert_array(ALLOWED_PATTERNS[enemy])
          . override_failure_message("%s: %s %s" % [id, enemy, layer["pattern"]])
          . contains([layer["pattern"]])
        )


func test_line_horiz_group_is_single_per_wave() -> void:
  # LineHorizMove は同じグループ全体で整列位置を決めるため、1 ウェーブに 2 群出すと位置が重なる
  for stage in STAGE_ENEMIES:
    for id in _stage_template_ids(stage):
      var groups := 0
      for layer in _templates[id]["layers"]:
        if layer["pattern"] == "line_horiz":
          groups += 1
      assert_int(groups).override_failure_message(id).is_less_equal(1)


func test_from_top_spawn_positions_do_not_overlap_within_wave() -> void:
  # from_top_spacing は横幅を count+1 等分した位置に出すため、同じウェーブで位置が重ならないこと
  for stage in STAGE_ENEMIES:
    for id in _stage_template_ids(stage):
      var taken := {}
      for layer in _templates[id]["layers"]:
        if layer["pattern"] != "from_top_spacing" or layer["enemy"] in LEAVES_SPAWN_POSITION:
          continue
        var count := int(layer["count"])
        for i in range(1, count + 1):
          # i / (count + 1) を約分した分数をキーにする
          var g := _gcd(i, count + 1)
          var key := "%d/%d" % [i / g, (count + 1) / g]
          (
            assert_bool(taken.has(key))
            . override_failure_message("%s overlaps at %s" % [id, key])
            . is_false()
          )
          taken[key] = true


func _gcd(a: int, b: int) -> int:
  while b != 0:
    var t := b
    b = a % b
    a = t
  return a


func test_first_and_third_stage_seeds_mix_dedicated_and_pool_waves() -> void:
  for chapter in STAGE_ENEMIES:
    for number in [1, 3]:
      var stage := _stage(chapter, number)
      assert_object(stage).is_not_null()
      var dedicated := 0
      var pooled := 0
      for part in _waves_in_seed(stage.fixed_seed):
        assert_bool(_templates.has(part)).override_failure_message(part).is_true()
        if part.contains("z"):
          continue
        if _templates[part].has("pool"):
          pooled += 1
        else:
          dedicated += 1
      var label := "%d-%d" % [chapter, number]
      assert_int(dedicated).override_failure_message(label).is_greater(0)
      # すべてを専用ウェーブにはしない
      assert_int(pooled).override_failure_message(label).is_greater(0)


func test_dedicated_waves_are_few_in_first_stage_and_many_in_third() -> void:
  for chapter in STAGE_ENEMIES:
    var pool_max := 0
    for id in _pool_template_ids(chapter):
      pool_max = max(pool_max, _enemy_count(id))

    var first := _dedicated_waves(_stage(chapter, 1))
    var third := _dedicated_waves(_stage(chapter, 3))
    for id in first:
      assert_int(_enemy_count(id)).override_failure_message(id).is_less_equal(
        MAX_FIRST_STAGE_DEDICATED_ENEMIES
      )
      assert_array(third).not_contains([id])
    for id in third:
      # x-3 専用はプールのどのウェーブよりも敵が多い
      assert_int(_enemy_count(id)).override_failure_message(id).is_greater(pool_max)
      assert_array(first).not_contains([id])


func _dedicated_waves(stage: StageData) -> Array:
  return _waves_in_seed(stage.fixed_seed).filter(
    func(part): return not part.contains("z") and not _templates[part].has("pool")
  )


func test_seeds_resolve_to_their_stage_environment() -> void:
  # StageManager._determine_current_stage() はシード中の "s6"〜"s2" を大きい順に探して背景・BGM を決める
  for chapter in STAGE_ENEMIES:
    for number in [1, 3]:
      var seed_value := _stage(chapter, number).fixed_seed
      var resolved := 1
      for n in [6, 5, 4, 3, 2]:
        if seed_value.contains("s%d" % n):
          resolved = n
          break
      assert_int(resolved).is_equal(chapter)
