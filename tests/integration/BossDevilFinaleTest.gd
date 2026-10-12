# 6-1 魔族撃破後の演出（フェーズ4）の結合テスト
extends GdUnitTestSuite

const DEVIL_SCENE := preload("res://scenes/enemy/enemy_boss_devil.tscn")

var _devil: Node2D
var _dialogue_paths: Array[String] = []
var _flash_events: Array = []
var _sfx_events: Array[String] = []


func before_test():
  _dialogue_paths.clear()
  _flash_events.clear()
  _sfx_events.clear()

  StageSignals.request_dialogue.connect(_on_request_dialogue)
  StageSignals.request_hud_flash.connect(_on_request_hud_flash)
  StageSignals.sfx_play_requested.connect(_on_sfx_play_requested)

  _devil = DEVIL_SCENE.instantiate()
  add_child(_devil)
  await await_idle_frame()


func after_test():
  if StageSignals.request_dialogue.is_connected(_on_request_dialogue):
    StageSignals.request_dialogue.disconnect(_on_request_dialogue)
  if StageSignals.request_hud_flash.is_connected(_on_request_hud_flash):
    StageSignals.request_hud_flash.disconnect(_on_request_hud_flash)
  if StageSignals.sfx_play_requested.is_connected(_on_sfx_play_requested):
    StageSignals.sfx_play_requested.disconnect(_on_sfx_play_requested)
  if is_instance_valid(_devil):
    _devil.queue_free()


func _on_request_dialogue(_dialogue_data, finished_cb: Callable) -> void:
  if finished_cb.is_valid():
    finished_cb.call_deferred()


func _on_request_hud_flash(fade_duration) -> void:
  _flash_events.append(fade_duration)


func _on_sfx_play_requested(sfx_name: String, _pos: Vector2, _vol_db: float, _pitch: float) -> void:
  _sfx_events.append(sfx_name)


func _finale_patterns() -> Array[EnemyPatternResource]:
  var phase: PhaseResource = _devil.ai.phases[BossDevilAI.FINALE_PHASE_IDX]
  return phase.patterns


func test_finale_phase_dialogue_order() -> void:
  for pattern in _finale_patterns():
    if not pattern.dialogue_path.is_empty():
      _dialogue_paths.append(pattern.dialogue_path)

  # resolution3 はボス退場後にシード側のイベントとして流す
  assert_array(_dialogue_paths).is_equal(["s6d11.resolution", "s6d11.resolution2"])


func test_finale_phase_staging_steps() -> void:
  var patterns := _finale_patterns()
  assert_int(patterns.size()).is_equal(8)

  # resolution 終了後: 0.5s で下方向へ 200px
  var down := patterns[2]
  assert_int(down.movement_type).is_equal(EnemyPatternResource.MovementType.MOVE_DIRECTION)
  assert_float(down.move_angle).is_equal(90.0)
  assert_float(down.move_time).is_equal_approx(0.5, 0.001)
  assert_float(down.move_speed * down.move_time).is_equal_approx(200.0, 0.01)

  # 0.5s 停止
  var hold := patterns[3]
  assert_int(hold.movement_type).is_equal(EnemyPatternResource.MovementType.STAY_IN_PLACE)
  assert_float(hold.move_time).is_equal_approx(0.5, 0.001)

  # 0.2s で上方向へ 200px
  var up := patterns[4]
  assert_int(up.movement_type).is_equal(EnemyPatternResource.MovementType.MOVE_DIRECTION)
  assert_float(up.move_angle).is_equal(270.0)
  assert_float(up.move_time).is_equal_approx(0.2, 0.001)
  assert_float(up.move_speed * up.move_time).is_equal_approx(200.0, 0.01)

  # 跳ね上がり直後のパターン開始時にフラッシュと効果音を出す（1.5s 静止）
  assert_int(BossDevilAI.FINALE_FLASH_IDX).is_equal(6)
  assert_float(patterns[5].move_time).is_equal_approx(1.5, 0.001)

  # resolution2 終了後: 画面上へ退場
  var exit_pattern := patterns[7]
  assert_int(exit_pattern.movement_type).is_equal(
    EnemyPatternResource.MovementType.MOVE_TO_POSITION
  )
  assert_bool(exit_pattern.move_to.y < 0.0).is_true()

  # 演出パターン中はプレイヤー操作を止める（会話パターンは会話側で止まる）
  for idx in [2, 3, 4, 5, 7]:
    assert_bool(patterns[idx].block_player_control).is_true()


func test_finale_runs_to_boss_removal(timeout := 30000) -> void:
  var ai = _devil.ai
  ai._phase_idx = 3
  ai._next_phase()  # フェーズ4（撃破後の演出）へ
  await await_idle_frame()

  # 画面上中央への移動（3.0s）と resolution の間はフラッシュを出さない
  await await_millis(3300)
  assert_array(_flash_events).is_empty()

  # 下降 0.5s → 静止 0.5s → 上昇 0.2s を終えたタイミングでフラッシュ＋効果音
  await await_millis(1500)
  assert_array(_flash_events).is_equal([1])
  assert_array(_sfx_events).contains(["destroy_boss", "break_shield"])

  # 静止 1.5s → resolution2 → 退場 0.5s の後にボスが消える
  await await_millis(3000)
  assert_bool(is_instance_valid(_devil)).is_false()


func test_stage6_1_seed_plays_resolution3_after_boss() -> void:
  var select_data: StageSelectData = load("res://resources/data/stage_select_data.tres")
  var stage := select_data.get_stage_by_ids("chapter6", "stage6_1")
  assert_object(stage).is_not_null()
  # 雑魚ウェーブの構成は変わりうるため、シードは実データから読み、導入・ボス・後語りの位置だけを確認する
  assert_str(stage.fixed_seed).starts_with("Ds6d11.intro-")
  assert_str(stage.fixed_seed).ends_with("-s6z1-Cs6c1")

  var controller := StageController.new()
  add_child(controller)

  assert_bool(controller.start_stage(stage.fixed_seed)).is_true()
  assert_int(controller.get_total_events()).is_equal(stage.fixed_seed.split("-").size())

  controller.stop_stage()
  controller.queue_free()


func test_stage6_cutscene_plays_resolution3() -> void:
  # resolution2 からの間にプレイヤー操作が通らないよう、後語りはカットシーンとして流す
  var data := GameDataRegistry.get_cutscene_data("s6c1")
  assert_dict(data).is_not_empty()

  var dialogue_paths: Array[String] = []
  for step in data.get("steps", []):
    if step.get("type", "") == "dialogue":
      dialogue_paths.append(step["path"])
      assert_array(GameDataRegistry.get_dialogue_data(step["path"])).is_not_empty()

  assert_array(dialogue_paths).is_equal(["s6d11.resolution3"])


func test_resolution_starts_wind_bgm_on_first_line() -> void:
  var dialogue_data := DialogueConverter.get_dialogue_data_from_path("s6d11.resolution")
  assert_object(dialogue_data).is_not_null()

  var first_line: DialogueLine = dialogue_data.lines[0]
  assert_object(first_line.bgm).is_not_null()
  assert_str(first_line.bgm.resource_path).is_equal("res://assets/audio/bgm/stage5_bgm_wind.mp3")
  assert_float(first_line.bgm_volume_db).is_equal(-10.0)
  assert_float(first_line.bgm_fade_in).is_equal(2.0)

  # 以降の行では BGM を切り替えない
  for i in range(1, dialogue_data.lines.size()):
    assert_object(dialogue_data.lines[i].bgm).is_null()
