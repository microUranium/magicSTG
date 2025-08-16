extends WormBossAI
class_name BossSnakeAI

# パターン定義
@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
var _phase_idx: int = 0

@export var _bgm: AudioStream
@export var bgm_fade_in := 2.0

var phase1_patterns: Array[AttackPattern] = []


func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type
  current_state = MovementState.PATTERN
  get_parent().connect("change_body_attack", Callable(self, "_change_speed"))
  super._ready()


func _next_phase():
  if phases.is_empty():
    push_error("No phases defined in HarpyAI.")
    return

  _cancel_current_pattern()

  _phase_idx += 1

  if _phase_idx == 1:
    if enemy_node.has_method("setup"):
      enemy_node.setup()
    else:
      push_error("Enemy node does not have a setup method.")
    if not skip_bgm_change:
      StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト

  if _phase_idx >= phases.size():
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_request_change_background_scroll_speed(1000, 0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)
    enemy_node.connect("area_entered", Callable(enemy_node, "_on_area_entered"))
    current_state = MovementState.CHASE
    return

  var phase := phases[_phase_idx]
  patterns = phase.patterns
  loop_type = phase.loop_type
  _idx = 0

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return
  if _idx >= patterns.size() and _phase_idx <= 1:
    _next_phase()
  else:
    super._on_pattern_finished(cb_token)


func _change_speed(_phase_idx: int):
  if _phase_idx == 3:
    rush_speed *= 1.5
    chase_min_speed *= 1.5
    chase_max_speed *= 1.5
    circle_speed *= 1.5
    max_turn_rate *= 1.5
    circle_to_rush_time = 1
    circle_max_time = 1.5
