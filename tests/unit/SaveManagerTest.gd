class_name SaveManagerTest
extends GdUnitTestSuite

const TEST_SAVE_PATH := "user://test_save_manager.json"

# オートロードの状態を退避・復元するための保持領域
var _orig_save_path: String
var _orig_inventory: Array[ItemInstance]
var _orig_attack_cores: Array
var _orig_blessings: Array
var _orig_stage_select_data: StageSelectData
var _orig_progress: Dictionary
var _orig_current_stage: StageData


func before_test() -> void:
  _orig_save_path = SaveManager.save_path
  _orig_inventory = InventoryService.get_items()
  _orig_attack_cores = PlayerSaveData.get_attack_cores()
  _orig_blessings = PlayerSaveData.get_blessings()
  _orig_stage_select_data = StageDataManager.stage_select_data
  _orig_progress = StageDataManager.get_progress_dict()
  _orig_current_stage = StageDataManager.current_stage

  SaveManager.save_path = TEST_SAVE_PATH
  _remove_test_save()
  StageDataManager.stage_select_data = _build_stage_select_data()
  StageDataManager.apply_progress_dict({})


func after_test() -> void:
  _remove_test_save()
  SaveManager.save_path = _orig_save_path

  InventoryService.clear()
  for item in _orig_inventory:
    InventoryService.try_add(item)
  PlayerSaveData.apply_equipment(_typed(_orig_attack_cores), _typed(_orig_blessings))

  StageDataManager.stage_select_data = _orig_stage_select_data
  StageDataManager.apply_progress_dict(_orig_progress)
  StageDataManager.current_stage = _orig_current_stage


# ───────────────────────────────────
# Tests
# ───────────────────────────────────
func test_save_and_load_roundtrip_restores_inventory_and_equipment() -> void:
  var ac_equipped := _make_item("attackcore_magic_bullet", "ac_equipped")
  var ac_owned := _make_item("attackcore_fireball", "ac_owned")
  ac_owned.enchantments[ItemDb.get_enchantment_by_id("cooldown_pct")] = 2
  var bl_equipped := _make_item("blessing_shield", "bl_equipped")
  var bl_owned := _make_item("blessing_fortitude", "bl_owned")

  InventoryService.clear()
  InventoryService.try_add(ac_owned)
  InventoryService.try_add(bl_owned)
  PlayerSaveData.apply_equipment(_typed([ac_equipped]), _typed([bl_equipped]))

  assert_bool(SaveManager.save_game()).is_true()
  assert_bool(FileAccess.file_exists(TEST_SAVE_PATH)).is_true()

  # 状態を消してからロードし、元に戻ることを確認する
  InventoryService.clear()
  PlayerSaveData.clear_equipment()
  SaveManager.load_game()

  assert_array(_uids(InventoryService.get_items())).contains_exactly_in_any_order(
    ["ac_owned", "bl_owned"]
  )
  assert_array(_uids(PlayerSaveData.get_attack_cores())).contains_exactly(["ac_equipped"])
  assert_array(_uids(PlayerSaveData.get_blessings())).contains_exactly(["bl_equipped"])

  var loaded_owned: ItemInstance = _find_by_uid(InventoryService.get_items(), "ac_owned")
  assert_int(loaded_owned.enchantments[ItemDb.get_enchantment_by_id("cooldown_pct")]).is_equal(2)


func test_save_file_contains_version_progress_and_items() -> void:
  InventoryService.clear()
  InventoryService.try_add(_make_item("blessing_shield", "bl_owned"))
  PlayerSaveData.apply_equipment(
    _typed([_make_item("attackcore_magic_bullet", "ac_equipped")]), _typed([])
  )

  SaveManager.save_game()

  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
  assert_int(int(data["version"])).is_equal(SaveManager.SAVE_VERSION)
  assert_bool(data.has("progress")).is_true()
  assert_array(data["equipped"]).contains_exactly(["ac_equipped"])
  # 装備中のアイテムも所持品として保存される
  assert_int(data["inventory"]["attack_core"].size()).is_equal(1)
  assert_int(data["inventory"]["blessings"].size()).is_equal(1)


func test_save_and_load_roundtrip_restores_stage_progress() -> void:
  StageDataManager.current_stage = StageDataManager.get_stage_by_ids("c1", "s1_1")
  StageDataManager.mark_current_stage_cleared()
  SaveManager.save_game()

  # 解放状態を初期定義に戻してからロードする
  StageDataManager.stage_select_data = _build_stage_select_data()
  StageDataManager.apply_progress_dict({})
  SaveManager.load_game()

  assert_bool(StageDataManager.is_stage_cleared("c1", "s1_1")).is_true()
  assert_bool(StageDataManager.get_stage_by_ids("c1", "s1_2").is_unlocked).is_true()


func test_save_and_load_roundtrip_restores_dialogue_settings() -> void:
  StageDataManager.set_stage_cleared("c1", "s1_1", true)
  StageDataManager.set_dialogue_enabled(StageDataManager.get_stage_by_ids("c1", "s1_1"), true)
  SaveManager.save_game()

  StageDataManager.stage_select_data = _build_stage_select_data()
  StageDataManager.apply_progress_dict({})
  SaveManager.load_game()

  var stage := StageDataManager.get_stage_by_ids("c1", "s1_1")
  assert_bool(StageDataManager.is_dialogue_enabled(stage)).is_true()


func test_load_falls_back_to_default_when_save_missing() -> void:
  InventoryService.clear()
  PlayerSaveData.clear_equipment()

  SaveManager.load_game()

  _assert_default_equipment()


func test_load_falls_back_to_default_when_save_corrupted() -> void:
  var f := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
  f.store_string("not json")
  f.close()
  PlayerSaveData.clear_equipment()

  SaveManager.load_game()

  _assert_default_equipment()


func test_load_falls_back_to_default_when_inventory_key_missing() -> void:
  # 旧実装が書き出していた形式（inventory キー無し）は不正データとして扱う
  var f := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
  f.store_string(JSON.stringify({"attack_core": [], "blessings": []}))
  f.close()
  PlayerSaveData.clear_equipment()

  SaveManager.load_game()

  _assert_default_equipment()


func test_load_from_dict_rejects_missing_inventory() -> void:
  assert_bool(PlayerSaveData.load_from_dict({"equipped": []})).is_false()


func test_equipment_change_does_not_write_file() -> void:
  PlayerSaveData.apply_equipment(_typed([_make_item("attackcore_magic_bullet", "ac")]), _typed([]))

  assert_bool(FileAccess.file_exists(TEST_SAVE_PATH)).is_false()


# ───────────────────────────────────
# Helpers
# ───────────────────────────────────
func _assert_default_equipment() -> void:
  assert_array(_uids(PlayerSaveData.get_attack_cores())).contains_exactly(
    ["attackcore_magic_bullet_1", "attackcore_magic_bullet_2", "attackcore_magic_bullet_3"]
  )
  assert_array(_uids(PlayerSaveData.get_blessings())).contains_exactly(["blessing_shield_1"])


func _remove_test_save() -> void:
  if FileAccess.file_exists(TEST_SAVE_PATH):
    DirAccess.remove_absolute(TEST_SAVE_PATH)


func _make_item(proto_id: String, uid: String) -> ItemInstance:
  return ItemInstance.new(ItemDb.get_item_by_id(proto_id), uid)


func _typed(items: Array) -> Array[ItemInstance]:
  var result: Array[ItemInstance] = []
  for item in items:
    result.append(item)
  return result


func _uids(items: Array) -> Array:
  return items.map(func(item: ItemInstance): return item.uid)


func _find_by_uid(items: Array, uid: String) -> ItemInstance:
  for item: ItemInstance in items:
    if item.uid == uid:
      return item
  return null


func _build_stage_select_data() -> StageSelectData:
  var s1_1 := _make_stage("c1", "s1_1", true)
  var s1_2 := _make_stage("c1", "s1_2", false)
  var c1 := ChapterData.new()
  c1.chapter_id = "c1"
  c1.is_unlocked = true
  c1.stages.assign([s1_1, s1_2])

  var data := StageSelectData.new()
  data.chapters.assign([c1])
  return data


func _make_stage(chapter_id: String, stage_id: String, unlocked: bool) -> StageData:
  var stage := StageData.new()
  stage.chapter_id = chapter_id
  stage.stage_id = stage_id
  stage.is_unlocked = unlocked
  return stage
