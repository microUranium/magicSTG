extends Node2D
## ボスにオーバーレイ表示するHPバー（自己配線コンポーネント）。
##
## - シーンのボス配下に置くだけで、自身が HpNode.hp_changed と AI.phase_changed を
##   購読して表示を制御する。ボス側スクリプトはバーに触れる必要がない。
## - 表示可否は各フェーズの PhaseResource.show_hp_bar で決まる（登場/会話は非表示）。
## - mode:
##     SINGLE    … HP を単一プール [0, max_hp] として表示。初回表示時のみ 0→満タンを
##                 充填し、以降のフェーズではリセットしない。
##     PER_PHASE … 戦闘フェーズごとに区間 [low, high] を算出しリセット＆再充填する。
## - フェーズ開始時の充填は約 0.5s、対数的(EXPO/EASE_OUT)。
## - ボスが回転・拡大しても影響を受けないよう top_level で追従する。

enum Mode { SINGLE, PER_PHASE }

const FILL_DURATION := 0.5  # 充填アニメーションの所要時間（秒）

@export var mode: Mode = Mode.PER_PHASE
@export var follow_offset: Vector2 = Vector2(0, 70)  # ボス中心からのオフセット（下寄り）
@export var ai_path: NodePath = ^"../EnemyAI"
@export var hp_node_path: NodePath = ^"../HpNode"

@onready var _bar: TextureProgressBar = $ProgressBar

var _ai: Node = null
var _hp_node: Node = null
var _low_hp: int = 0
var _high_hp: int = 1
var _filling: bool = false
var _fill_tween: Tween = null
var _shown_once: bool = false  # SINGLE: 初回充填を済ませたか


func _ready() -> void:
  top_level = true  # 親（ボス）の回転・拡大の影響を受けない
  _bar.max_value = 100.0
  _bar.value = 0.0
  visible = false

  _ai = get_node_or_null(ai_path)
  _hp_node = get_node_or_null(hp_node_path)

  if _hp_node and _hp_node.has_signal("hp_changed"):
    _hp_node.hp_changed.connect(_on_hp_changed)
  if _ai and _ai.has_signal("phase_changed"):
    _ai.phase_changed.connect(_on_phase_changed)

  # 現在フェーズ（通常は登場/会話フェーズ）で初期表示状態を反映
  if _ai and "_phase_idx" in _ai:
    _on_phase_changed(_ai._phase_idx)


func _process(_delta: float) -> void:
  var parent := get_parent() as Node2D
  if parent:
    global_position = parent.global_position + follow_offset


# --- 信号ハンドラ ---------------------------------------------------------


func _on_phase_changed(phase_idx: int) -> void:
  if _ai == null or _hp_node == null:
    return

  var phases = _ai.phases
  if phase_idx < 0 or phase_idx >= phases.size():
    hide_bar()
    return

  var phase: PhaseResource = phases[phase_idx]
  if phase == null or not phase.show_hp_bar:
    hide_bar()
    return

  visible = true
  var max_hp: int = _hp_node.max_hp
  var cur_hp: int = _hp_node.current_hp

  if mode == Mode.SINGLE:
    if not _shown_once:
      _shown_once = true
      _begin_segment(0, max_hp, cur_hp, true)  # 初回のみリセット＆充填
    else:
      _begin_segment(0, max_hp, cur_hp, false)  # 再表示は継続（リセットなし）
  else:  # PER_PHASE
    if phase.bar_merge_with_previous:
      # 区間を変えず現在値を継続（p5/p6統合など）
      _set_value_no_reset(cur_hp)
    else:
      var seg := _compute_segment(phase_idx, max_hp)
      _begin_segment(seg.x, seg.y, cur_hp, true)


func _on_hp_changed(current_hp: int, _max_hp: int) -> void:
  if not visible:
    return
  update_hp(current_hp)


# --- 表示制御 -------------------------------------------------------------


## 区間内のHP減少を即時反映する（充填アニメ中は無視）。
func update_hp(current_hp: int) -> void:
  if _filling:
    return
  _bar.value = _ratio_to_value(current_hp)


## バーを隠す。
func hide_bar() -> void:
  visible = false


# --- 内部処理 -------------------------------------------------------------


## 区間 [low, high] を設定する。reset=true なら 0 から対数的に充填、false なら現在値へ即反映。
func _begin_segment(low_hp: int, high_hp: int, current_hp: int, reset: bool) -> void:
  _low_hp = low_hp
  _high_hp = high_hp

  if _fill_tween and _fill_tween.is_valid():
    _fill_tween.kill()

  if reset:
    var target := _ratio_to_value(current_hp)
    _bar.value = 0.0
    _filling = true
    _fill_tween = create_tween()
    (
      _fill_tween
      . tween_property(_bar, "value", target, FILL_DURATION)
      . set_trans(Tween.TRANS_EXPO)
      . set_ease(Tween.EASE_OUT)
    )
    _fill_tween.finished.connect(func(): _filling = false)
  else:
    _filling = false
    _bar.value = _ratio_to_value(current_hp)


## 区間を変えずに現在値だけ反映（マージ継続用）。
func _set_value_no_reset(current_hp: int) -> void:
  if _fill_tween and _fill_tween.is_valid():
    _fill_tween.kill()
  _filling = false
  _bar.value = _ratio_to_value(current_hp)


## PER_PHASE のフェーズ区間 [low, high]（HP値）を算出する。
##   high = 直前の「表示ありかつ非マージ」フェーズの end_hp_ratio（無ければ満タン 1.0）
##   low  = このフェーズの end_hp_ratio
func _compute_segment(phase_idx: int, max_hp: int) -> Vector2i:
  var phases = _ai.phases
  var high_ratio := 1.0
  for i in range(phase_idx - 1, -1, -1):
    var p: PhaseResource = phases[i]
    if p and p.show_hp_bar and not p.bar_merge_with_previous:
      high_ratio = p.end_hp_ratio
      break
  var low_hp := int(round(max_hp * phases[phase_idx].end_hp_ratio))
  var high_hp := int(round(max_hp * high_ratio))
  return Vector2i(low_hp, high_hp)


func _ratio_to_value(current_hp: int) -> float:
  var span := float(_high_hp - _low_hp)
  if span <= 0.0:
    return 0.0
  var ratio: float = clamp((float(current_hp) - _low_hp) / span, 0.0, 1.0)
  return ratio * 100.0
