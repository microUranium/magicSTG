# 会話を省略した熊（5-2 の最終ウェーブ）の登場演出の結合テスト
extends GdUnitTestSuite

const BEAR_SCENE := preload("res://scenes/enemy/enemy_boss_bear.tscn")
const PHASE_TIMEOUT_MS := 8000

var _bear: Node2D
var _bullet_root: Node2D
var _pause_events: Array = []


func before_test():
  _pause_events.clear()
  StageSignals.cutscene_pause_requested.connect(_on_cutscene_pause_requested)
  _bullet_root = auto_free(Node2D.new())
  add_child(_bullet_root)
  TargetService.set_bullet_parent(_bullet_root)


func after_test():
  if StageSignals.cutscene_pause_requested.is_connected(_on_cutscene_pause_requested):
    StageSignals.cutscene_pause_requested.disconnect(_on_cutscene_pause_requested)
  if is_instance_valid(_bear):
    _bear.queue_free()
  _bear = null
  TargetService.set_bullet_parent(null)


func _on_cutscene_pause_requested(paused: bool) -> void:
  _pause_events.append(paused)


func test_skip_dialogue_bear_never_blocks_player_until_battle_starts() -> void:
  _bear = BEAR_SCENE.instantiate()
  _bear.get_node("EnemyAI").skip_dialogue = true
  add_child(_bear)

  # 登場移動 → 演出用の待機パターン → 戦闘フェーズ（phase 1）まで進める
  var ai = _bear.get_node("EnemyAI")
  var waited := 0
  while ai._phase_idx == 0 and waited < PHASE_TIMEOUT_MS:
    await await_millis(100)
    waited += 100

  assert_int(ai._phase_idx).is_equal(1)
  # 演出用パターン（block_player_control）を通っても操作ロックは要求されない
  assert_array(_pause_events).not_contains([true])
