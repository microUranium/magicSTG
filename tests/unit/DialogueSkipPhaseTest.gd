# ステージ選択画面でダイアログを無効にしたときの、会話省略の共通処理の単体テスト
extends GdUnitTestSuite

var _ai: EnemyPatternedAIBase
var _enemy: Node2D
var _original_current_stage: StageData


func before_test():
  _original_current_stage = StageDataManager.current_stage
  _ai = auto_free(EnemyPatternedAIBase.new())
  _enemy = auto_free(Node2D.new())
  _ai.enemy_node = _enemy


func after_test():
  StageDataManager.current_stage = _original_current_stage


func _move_to(pos: Vector2) -> EnemyPatternResource:
  var pattern := EnemyPatternResource.new()
  pattern.movement_type = EnemyPatternResource.MovementType.MOVE_TO_POSITION
  pattern.move_to = pos
  return pattern


func _dialogue(path: String) -> EnemyPatternResource:
  var pattern := EnemyPatternResource.new()
  pattern.movement_type = EnemyPatternResource.MovementType.STAY_IN_PLACE
  pattern.move_to = Vector2(999, 999)  # 会話パターンの移動先は使われない
  pattern.dialogue_path = path
  return pattern


func _stage(dialogue_enabled: bool) -> StageData:
  var stage := StageData.new()
  stage.dialogue_enabled = dialogue_enabled
  return stage


func test_is_dialogue_skipped_follows_current_stage() -> void:
  StageDataManager.current_stage = null
  assert_bool(StageDataManager.is_dialogue_skipped()).is_false()

  StageDataManager.current_stage = _stage(true)
  assert_bool(StageDataManager.is_dialogue_skipped()).is_false()

  StageDataManager.current_stage = _stage(false)
  assert_bool(StageDataManager.is_dialogue_skipped()).is_true()


func test_enter_tree_enables_skip_dialogue_when_stage_disables_dialogue() -> void:
  StageDataManager.current_stage = _stage(false)

  _ai._enter_tree()

  assert_bool(_ai.skip_dialogue).is_true()


func test_enter_tree_keeps_skip_dialogue_when_stage_enables_dialogue() -> void:
  StageDataManager.current_stage = _stage(true)

  _ai._enter_tree()
  assert_bool(_ai.skip_dialogue).is_false()

  # 敵定義で個別に省略指定された個体（ランダムステージのボス等）は省略のまま
  _ai.skip_dialogue = true
  _ai._enter_tree()
  assert_bool(_ai.skip_dialogue).is_true()


func test_skip_dialogue_phase_warps_to_last_move_destination() -> void:
  _ai.skip_dialogue = true
  _enemy.global_position = Vector2(100, 100)
  _ai.patterns = [
    _move_to(Vector2(200, 300)), _dialogue("a.b"), _move_to(Vector2(448, 144)), _dialogue("a.c")
  ]

  assert_bool(_ai._try_skip_dialogue_phase()).is_true()
  assert_vector(_enemy.global_position).is_equal(Vector2(448, 144))


func test_skip_dialogue_phase_keeps_position_without_move() -> void:
  _ai.skip_dialogue = true
  _enemy.global_position = Vector2(100, 100)
  _ai.patterns = [_dialogue("a.b")]

  assert_bool(_ai._try_skip_dialogue_phase()).is_true()
  assert_vector(_enemy.global_position).is_equal(Vector2(100, 100))


func test_battle_phase_is_not_skipped() -> void:
  _ai.skip_dialogue = true
  _enemy.global_position = Vector2(100, 100)
  _ai.patterns = [_move_to(Vector2(200, 300))]

  assert_bool(_ai._try_skip_dialogue_phase()).is_false()
  assert_vector(_enemy.global_position).is_equal(Vector2(100, 100))


func test_dialogue_phase_is_not_skipped_without_skip_dialogue() -> void:
  _ai.skip_dialogue = false
  _enemy.global_position = Vector2(100, 100)
  _ai.patterns = [_move_to(Vector2(448, 144)), _dialogue("a.b")]

  assert_bool(_ai._try_skip_dialogue_phase()).is_false()
  assert_vector(_enemy.global_position).is_equal(Vector2(100, 100))
