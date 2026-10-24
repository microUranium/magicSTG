# ステージ選択画面でダイアログを無効にしたときの、章ボスの演出省略の結合テスト
extends GdUnitTestSuite

const HARPY_SCENE := preload("res://scenes/enemy/harpy.tscn")
const VAMPIRE_SCENE := preload("res://scenes/enemy/enemy_boss_vampire.tscn")
const HARPY_SWAMP_SCENE := preload("res://scenes/enemy/enemy_harpy_swamp.tscn")
const BIRD_SWAMP_SCENE := preload("res://scenes/enemy/enemy_boss_bird_swamp.tscn")
const DOLL_SCENE := preload("res://scenes/enemy/enemy_boss_doll.tscn")
const DEVIL_SCENE := preload("res://scenes/enemy/enemy_boss_devil.tscn")
const DEVIL_ENHANCED_SCENE := preload("res://scenes/enemy/enemy_boss_devil_enhanced.tscn")

const PHASE_TIMEOUT_MS := 8000
const BATTLE_START_POSITION := Vector2(448, 144)

var _scene_root: Node2D
var _player_stub: Node2D
var _dialogue_count := 0
var _destroy_bullet_count := 0
var _sfx_events: Array[String] = []
var _bgm_streams: Array = []
var _bgm_stop_count := 0


func before_test():
  _dialogue_count = 0
  _destroy_bullet_count = 0
  _sfx_events.clear()
  _bgm_streams.clear()
  _bgm_stop_count = 0

  # 分身（コウモリ）等は current_scene に追加されるため、テスト用のシーンを用意する
  _scene_root = Node2D.new()
  get_tree().root.add_child(_scene_root)
  get_tree().current_scene = _scene_root
  TargetService.set_bullet_parent(_scene_root)

  _player_stub = Node2D.new()
  _player_stub.global_position = Vector2(448, 748)
  _scene_root.add_child(_player_stub)
  TargetService.register_player(_player_stub)

  StageSignals.request_dialogue.connect(_on_request_dialogue)
  StageSignals.destroy_bullet.connect(_on_destroy_bullet)
  StageSignals.sfx_play_requested.connect(_on_sfx_play_requested)
  StageSignals.bgm_play_requested.connect(_on_bgm_play_requested)
  StageSignals.bgm_stop_requested.connect(_on_bgm_stop_requested)


func after_test():
  for connection in [
    [StageSignals.request_dialogue, _on_request_dialogue],
    [StageSignals.destroy_bullet, _on_destroy_bullet],
    [StageSignals.sfx_play_requested, _on_sfx_play_requested],
    [StageSignals.bgm_play_requested, _on_bgm_play_requested],
    [StageSignals.bgm_stop_requested, _on_bgm_stop_requested],
  ]:
    if connection[0].is_connected(connection[1]):
      connection[0].disconnect(connection[1])
  TargetService.unregister_player()
  TargetService.set_bullet_parent(null)
  get_tree().current_scene = null
  if is_instance_valid(_scene_root):
    _scene_root.queue_free()


func _on_request_dialogue(_dd, finished_cb: Callable) -> void:
  _dialogue_count += 1
  if finished_cb.is_valid():
    finished_cb.call_deferred()


func _on_destroy_bullet() -> void:
  _destroy_bullet_count += 1


func _on_sfx_play_requested(sfx_name: String, _pos: Vector2, _vol_db: float, _pitch: float) -> void:
  _sfx_events.append(sfx_name)


func _on_bgm_play_requested(stream: AudioStream, _fade_time: float, _maxdb: float) -> void:
  _bgm_streams.append(stream)


func _on_bgm_stop_requested(_fade_time: float) -> void:
  _bgm_stop_count += 1


func _spawn_skipping_boss(scene: PackedScene) -> Node2D:
  var boss := scene.instantiate() as Node2D
  boss.get_node("EnemyAI").skip_dialogue = true
  _scene_root.add_child(boss)
  return boss


func _wait_for_phase(ai: Node, phase_idx: int) -> void:
  var waited := 0
  while is_instance_valid(ai) and ai._phase_idx < phase_idx and waited < PHASE_TIMEOUT_MS:
    await await_millis(100)
    waited += 100


func _reset_effect_events() -> void:
  _destroy_bullet_count = 0
  _sfx_events.clear()


func test_harpy_starts_battle_after_entrance_and_skips_dialogue_phase() -> void:
  var harpy := _spawn_skipping_boss(HARPY_SCENE)
  var ai = harpy.get_node("EnemyAI")

  await _wait_for_phase(ai, 1)
  assert_int(ai._phase_idx).is_equal(1)
  assert_array(_bgm_streams).is_equal([ai._bgm])

  _reset_effect_events()
  harpy.on_hp_changed(1, 100)  # HP 50% 以下 → 会話フェーズ(2)を省略して phase 3 へ

  assert_int(ai._phase_idx).is_equal(3)
  assert_vector(harpy.global_position).is_equal(BATTLE_START_POSITION)
  assert_array(_sfx_events).contains(["power_up_boss"]).not_contains(["destroy_boss"])
  assert_int(_destroy_bullet_count).is_equal(0)
  assert_int(_dialogue_count).is_equal(0)


func test_vampire_keeps_bat_scene_and_skips_dialogue() -> void:
  var vampire := _spawn_skipping_boss(VAMPIRE_SCENE)
  var ai = vampire.get_node("EnemyAI")

  await _wait_for_phase(ai, 1)
  assert_int(ai._phase_idx).is_equal(1)

  _reset_effect_events()
  vampire.on_hp_changed(70, 100)  # HP 80% 以下 → phase 2

  # 中央へ即時移動し、コウモリを出すパターンから始まる
  assert_int(ai._phase_idx).is_equal(2)
  assert_int(ai._idx).is_equal(BossVampireAI.DECOY_PATTERN_IDX + 1)
  assert_vector(vampire.global_position).is_equal(BATTLE_START_POSITION)
  assert_int(ai._decoys.size()).is_greater(0)
  assert_array(_sfx_events).not_contains(["destroy_boss"])
  assert_int(_destroy_bullet_count).is_equal(0)

  # コウモリを出し終えたら会話を挟まず phase 3 へ
  await _wait_for_phase(ai, 3)
  assert_int(ai._phase_idx).is_equal(3)

  vampire.on_hp_changed(30, 100)  # HP 40% 以下 → 会話フェーズ(4)を省略して phase 5 へ
  assert_int(ai._phase_idx).is_equal(5)
  assert_vector(vampire.global_position).is_equal(BATTLE_START_POSITION)
  assert_int(_dialogue_count).is_equal(0)


func test_bird_swamp_enters_from_top_without_harpy() -> void:
  var harpy := _spawn_skipping_boss(HARPY_SWAMP_SCENE)
  var bird := _spawn_skipping_boss(BIRD_SWAMP_SCENE)
  var ai = bird.get_node("EnemyAI")

  assert_bool(harpy.is_queued_for_deletion()).is_true()

  # 下画面からの突進を行わず、画面上から降りてきて戦闘フェーズ(3)を始める
  await await_millis(500)
  assert_int(ai._phase_idx).is_equal(0)
  assert_float(bird.global_position.y).is_less(BATTLE_START_POSITION.y)

  await _wait_for_phase(ai, 3)
  assert_int(ai._phase_idx).is_equal(3)
  assert_array(_bgm_streams).is_equal([ai._bgm])
  assert_int(_dialogue_count).is_equal(0)


func test_doll_switches_to_boss_bgm_without_storm_and_laugh() -> void:
  var doll := _spawn_skipping_boss(DOLL_SCENE)
  var ai = doll.get_node("EnemyAI")

  await _wait_for_phase(ai, 1)
  assert_int(ai._phase_idx).is_equal(1)

  assert_array(_bgm_streams).is_equal([ai._bgm])
  assert_int(_bgm_stop_count).is_equal(0)
  assert_array(_sfx_events).not_contains(["girl_laugh"])
  assert_int(_dialogue_count).is_equal(0)


func test_devil_is_defeated_without_finale() -> void:
  var devil := _spawn_skipping_boss(DEVIL_SCENE)
  var ai = devil.get_node("EnemyAI")

  await _wait_for_phase(ai, 1)
  assert_int(ai._phase_idx).is_equal(1)

  devil.on_hp_changed(40, 100)  # HP 50% 以下 → 会話フェーズ(2)を省略して phase 3 へ
  assert_int(ai._phase_idx).is_equal(3)
  assert_vector(devil.global_position).is_equal(BATTLE_START_POSITION)

  devil.on_hp_changed(0, 100)
  assert_int(ai._phase_idx).is_equal(3)  # 撃破後演出（phase 4）には進まない
  assert_bool(devil.is_queued_for_deletion()).is_true()
  assert_int(_dialogue_count).is_equal(0)


func test_devil_enhanced_skips_dialogue_phases() -> void:
  var devil := _spawn_skipping_boss(DEVIL_ENHANCED_SCENE)
  var ai = devil.get_node("EnemyAI")

  await _wait_for_phase(ai, 1)
  assert_int(ai._phase_idx).is_equal(1)

  _reset_effect_events()
  devil.on_hp_changed(85, 100)  # HP 90% 以下 → 会話フェーズ(2)を省略して phase 3 へ

  assert_int(ai._phase_idx).is_equal(3)
  assert_vector(devil.global_position).is_equal(BATTLE_START_POSITION)
  assert_array(_sfx_events).contains(["power_up_boss"]).not_contains(["destroy_boss"])
  assert_int(_destroy_bullet_count).is_equal(0)
  assert_int(_dialogue_count).is_equal(0)


func test_devil_enhanced_keeps_final_phase_barrier_cores() -> void:
  var devil := _spawn_skipping_boss(DEVIL_ENHANCED_SCENE)
  var ai = devil.get_node("EnemyAI")

  await _wait_for_phase(ai, 1)
  devil.on_hp_changed(85, 100)  # → phase 3
  devil.on_hp_changed(50, 100)  # HP 60% 以下 → 会話フェーズ(4)を省略して phase 5（ラッシュ開始）
  assert_int(ai._phase_idx).is_equal(5)

  devil.on_hp_changed(5, 100)  # HP 10% 以下 → 会話フェーズ(6)を省略して phase 7 へ
  assert_int(ai._phase_idx).is_equal(7)
  assert_int(ai._pattern_cores.size()).is_greater(0)

  # phase 5 のラッシュが待機明けに中断しても、phase 7 のバリア弾のコアは消さない
  await await_millis(1500)
  assert_int(ai._phase_idx).is_equal(7)
  assert_int(ai._pattern_cores.size()).is_greater(0)


func test_bird_swamp_powers_up_on_final_rush_phase_when_skipping() -> void:
  var bird := _spawn_skipping_boss(BIRD_SWAMP_SCENE)
  var ai = bird.get_node("EnemyAI")

  await _wait_for_phase(ai, 3)
  bird.on_hp_changed(70, 100)  # HP 80% 以下 → 会話フェーズ(4)を省略して phase 5 へ
  assert_int(ai._phase_idx).is_equal(5)

  _reset_effect_events()
  bird.on_hp_changed(20, 100)  # HP 25% 以下 → 会話フェーズ(6)を省略して突進フェーズ(7)へ
  assert_int(ai._phase_idx).is_equal(7)
  assert_array(_sfx_events).contains(["power_up_boss"])


func test_bird_swamp_powers_up_on_final_rush_phase_without_skipping() -> void:
  var bird := BIRD_SWAMP_SCENE.instantiate() as Node2D
  _scene_root.add_child(bird)
  var ai = bird.get_node("EnemyAI")
  await await_idle_frame()

  _reset_effect_events()
  ai._phase_idx = 6  # 会話フェーズ(6)の終了 → 突進フェーズ(7)
  ai._next_phase()

  assert_int(ai._phase_idx).is_equal(7)
  assert_array(_sfx_events).contains(["power_up_boss"])
