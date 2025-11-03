extends EnemyPatternedAIBase
class_name EnemyHarpySwampAI

signal phases_changed

@export var phases: Array[PhaseResource] = []  # 各 Phase のパターンリソース
var _phase_idx := 0


func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type
  super._ready()


func _next_phase():
  if phases.is_empty():
    push_error("No phases defined in HarpyAI.")
    return

  _cancel_current_pattern()

  _phase_idx += 1
  if _phase_idx >= phases.size():
    return

  var phase := phases[_phase_idx]
  patterns = phase.patterns
  loop_type = phase.loop_type
  _idx = 0

  _next_pattern()


func _on_pattern_finished(cb_token: int):
  if cb_token != _token:  # 重複防止
    return

  if _idx >= patterns.size() and (_phase_idx == 0 or _phase_idx == 1):
    _next_phase()
    phases_changed.emit()
  elif _idx >= phases.size() and _phase_idx == 2:
    enemy_node.queue_free()
  else:
    super._on_pattern_finished(cb_token)
