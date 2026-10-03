# 演出パターン中のプレイヤー操作停止の単体テスト
extends GdUnitTestSuite

var _root: Node2D
var _ai: EnemyPatternedAIBase
var _events: Array = []


func before_test():
  _events.clear()
  StageSignals.cutscene_pause_requested.connect(_on_cutscene_pause_requested)


func after_test():
  if StageSignals.cutscene_pause_requested.is_connected(_on_cutscene_pause_requested):
    StageSignals.cutscene_pause_requested.disconnect(_on_cutscene_pause_requested)
  if is_instance_valid(_root):
    _root.queue_free()
    _root = null
  _ai = null


func _on_cutscene_pause_requested(paused: bool) -> void:
  _events.append(paused)


func _make_pattern(block_player_control: bool, move_time: float) -> EnemyPatternResource:
  var pattern := EnemyPatternResource.new()
  pattern.movement_type = EnemyPatternResource.MovementType.STAY_IN_PLACE
  pattern.move_time = move_time
  pattern.block_player_control = block_player_control
  return pattern


func _setup_ai(patterns: Array[EnemyPatternResource]) -> void:
  _root = Node2D.new()
  _root.name = "CutsceneTestEnemy"
  add_child(_root)

  _ai = EnemyPatternedAIBase.new()
  _ai.name = "EnemyAI"
  _ai.patterns = patterns
  _root.add_child(_ai)


func test_block_player_control_defaults_to_false() -> void:
  var pattern := EnemyPatternResource.new()

  assert_bool(pattern.block_player_control).is_false()


func test_blocking_pattern_requests_pause_on_start() -> void:
  _setup_ai([_make_pattern(true, 5.0)])

  await await_idle_frame()

  assert_array(_events).is_equal([true])


func test_non_blocking_pattern_does_not_request_pause() -> void:
  _setup_ai([_make_pattern(false, 5.0)])

  await await_idle_frame()

  assert_array(_events).is_empty()


func test_pause_is_released_when_blocking_pattern_finishes() -> void:
  _setup_ai([_make_pattern(true, 0.1), _make_pattern(false, 5.0)])

  await await_millis(300)

  assert_array(_events).is_equal([true, false])


func test_cancel_current_pattern_releases_pause() -> void:
  _setup_ai([_make_pattern(true, 5.0)])
  await await_idle_frame()

  _ai._cancel_current_pattern()

  assert_array(_events).is_equal([true, false])


func test_removing_enemy_releases_pause() -> void:
  _setup_ai([_make_pattern(true, 5.0)])
  await await_idle_frame()

  _root.queue_free()
  _root = null
  await await_idle_frame()

  assert_array(_events).is_equal([true, false])


func test_boss_cutscene_patterns_block_player_control() -> void:
  # セリフ間の演出パターンにフラグが設定されていること
  var expected := {
    "res://scenes/enemy/enemy_boss_vampire.tscn": 1,
    "res://scenes/enemy/enemy_boss_doll.tscn": 1,
    "res://scenes/enemy/enemy_boss_devil.tscn": 1,
  }
  for scene_path in expected.keys():
    var packed := load(scene_path) as PackedScene
    assert_object(packed).is_not_null()
    assert_int(_count_blocking_patterns(packed)).is_equal(expected[scene_path])


func _count_blocking_patterns(packed: PackedScene) -> int:
  var count := 0
  var state := packed.get_state()
  for node_idx in range(state.get_node_count()):
    for prop_idx in range(state.get_node_property_count(node_idx)):
      if state.get_node_property_name(node_idx, prop_idx) != "phases":
        continue
      for phase in state.get_node_property_value(node_idx, prop_idx):
        for pattern in phase.patterns:
          if pattern.block_player_control:
            count += 1
  return count


func test_stage_controller_pauses_player_on_cutscene_request() -> void:
  var controller := StageController.new()
  add_child(controller)
  var player := _StubPausablePlayer.new()
  player.add_to_group("player_controllable")
  add_child(player)

  StageSignals.emit_cutscene_pause_requested(true)
  assert_bool(player.paused).is_true()

  StageSignals.emit_cutscene_pause_requested(false)
  assert_bool(player.paused).is_false()

  player.queue_free()
  controller.queue_free()


class _StubPausablePlayer:
  extends Node

  var paused: bool = false

  func set_paused(value: bool) -> void:
    paused = value
