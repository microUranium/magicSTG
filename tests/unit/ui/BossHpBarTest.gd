# === ボスHPバー（自己配線・SINGLE/PER_PHASE）テスト ===
extends GdUnitTestSuite

const BossHpBarScene = preload("res://scenes/ui/boss_hp_bar.tscn")
const PhaseResourceScript = preload("res://scripts/systems/PhaseResource.gd")
const StubPhaseAIScript = preload("res://tests/stubs/StubPhaseAI.gd")
const HpNodeScript = preload("res://scripts/player/HpNode.gd")

const FILL_WAIT_MS := 700  # 充填アニメ(0.5s)完了を待つ余裕

var _boss: Node2D
var _ai  # StubPhaseAI（新規class_nameは -d 実行時に未キャッシュのため型注釈なし）
var _hp: Node
var _bar: Node2D


func _make_phase(show_bar: bool, end_ratio: float, merge := false):
  var p = PhaseResourceScript.new()
  p.show_hp_bar = show_bar
  p.end_hp_ratio = end_ratio
  p.bar_merge_with_previous = merge
  return p


# ボス配下ツリー（EnemyAI / HpNode / BossHpBar）を構築する。
# BossHpBar は _ready で兄弟を解決するため、先に AI/HpNode を追加してから設置する。
func _build(mode: int, phases: Array, max_hp: int) -> void:
  _boss = Node2D.new()
  add_child(_boss)

  _ai = StubPhaseAIScript.new()
  _ai.name = "EnemyAI"
  _ai.phases = phases
  _ai._phase_idx = 0
  _boss.add_child(_ai)

  _hp = HpNodeScript.new()
  _hp.name = "HpNode"
  _hp.max_hp = max_hp
  _boss.add_child(_hp)

  _bar = BossHpBarScene.instantiate()
  _bar.mode = mode
  _boss.add_child(_bar)


func _enter_phase(idx: int) -> void:
  _ai._phase_idx = idx
  _ai.phase_changed.emit(idx)


func _value() -> float:
  return (_bar.get_node("ProgressBar") as TextureProgressBar).value


func after_test() -> void:
  if is_instance_valid(_boss):
    _boss.queue_free()


# --- SINGLE モード -------------------------------------------------------


func test_single_hidden_on_intro_phase() -> void:
  _build(0, [_make_phase(false, 0.0), _make_phase(true, 0.0)], 100)
  await await_idle_frame()
  # 初期フェーズ0(show=false)は非表示
  assert_bool(_bar.visible).is_false()


func test_single_shows_and_fills_on_combat_phase() -> void:
  _build(0, [_make_phase(false, 0.0), _make_phase(true, 0.0)], 100)
  await await_idle_frame()

  _enter_phase(1)
  assert_bool(_bar.visible).is_true()
  await await_millis(FILL_WAIT_MS)
  # HP満タン→[0,100]で100%
  assert_float(_value()).is_equal_approx(100.0, 0.5)


func test_single_tracks_hp_over_full_pool() -> void:
  _build(0, [_make_phase(false, 0.0), _make_phase(true, 0.0)], 100)
  await await_idle_frame()
  _enter_phase(1)
  await await_millis(FILL_WAIT_MS)

  _hp.take_damage(30)  # 70/100
  assert_float(_value()).is_equal_approx(70.0, 0.01)


# --- PER_PHASE モード ----------------------------------------------------


func test_perphase_first_segment_normalized() -> void:
  # phases: 0=intro, 1=combat(end0.5), 2=stop, 3=combat(end0.0)
  var phases = [
    _make_phase(false, 0.0),
    _make_phase(true, 0.5),
    _make_phase(false, 0.0),
    _make_phase(true, 0.0),
  ]
  _build(1, phases, 400)
  await await_idle_frame()

  _enter_phase(1)  # 区間 [200,400]
  await await_millis(FILL_WAIT_MS)
  assert_float(_value()).is_equal_approx(100.0, 0.5)  # cur=400 → 満タン

  _hp.take_damage(100)  # 300 → (300-200)/200 = 50%
  assert_float(_value()).is_equal_approx(50.0, 0.01)


func test_perphase_second_segment_uses_prev_boundary() -> void:
  var phases = [
    _make_phase(false, 0.0),
    _make_phase(true, 0.5),
    _make_phase(false, 0.0),
    _make_phase(true, 0.0),
  ]
  _build(1, phases, 400)
  await await_idle_frame()

  _hp.current_hp = 200  # 50%まで削れた状態でフェーズ3へ
  _enter_phase(3)  # 区間 [0,200]（high=phase1 end0.5）
  await await_millis(FILL_WAIT_MS)
  assert_float(_value()).is_equal_approx(100.0, 0.5)  # cur=200 → 区間満タン

  _hp.take_damage(100)  # 100 → (100-0)/200 = 50%
  assert_float(_value()).is_equal_approx(50.0, 0.01)


func test_perphase_merge_keeps_segment() -> void:
  # p1=combat(end0.0) を「区間[0,400]」とし、p2 をマージ継続
  var phases = [
    _make_phase(false, 0.0),
    _make_phase(true, 0.0),
    _make_phase(true, 0.0, true),  # merge
  ]
  _build(1, phases, 400)
  await await_idle_frame()

  _enter_phase(1)  # 区間 [0,400]
  await await_millis(FILL_WAIT_MS)
  _hp.current_hp = 100  # 25%
  _bar._on_hp_changed(100, 400)
  assert_float(_value()).is_equal_approx(25.0, 0.01)

  _enter_phase(2)  # マージ：リセットせず [0,400] 継続、25%のまま
  assert_float(_value()).is_equal_approx(25.0, 0.01)


func test_hidden_phase_hides_bar() -> void:
  var phases = [_make_phase(false, 0.0), _make_phase(true, 0.5), _make_phase(false, 0.0)]
  _build(1, phases, 400)
  await await_idle_frame()

  _enter_phase(1)
  assert_bool(_bar.visible).is_true()
  _enter_phase(2)  # show=false → 非表示
  assert_bool(_bar.visible).is_false()
