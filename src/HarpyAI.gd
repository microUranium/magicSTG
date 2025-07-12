extends "res://src/EnemyPatternedAIBase.gd"
class_name HarpyAI

@export var phases: Array[PhaseResource] = [] # 各 Phase のパターンリソース
@export var attack_core_phase1: Array[PackedScene] = [] # Phase 1 の攻撃コアシーン
@export var attack_core_phase3_1: Array[PackedScene] = [] # Phase 3 の攻撃コアシーン
@export var attack_core_phase3_2: Array[PackedScene] = [] # Phase 3 の攻撃コアシーン
@export var attack_core_slot: AttackCoreSlot = null # 攻撃コアをセットするスロット

@export var _bgm : AudioStream
@export var bgm_fade_in := 2.0

var _phase_idx := 0

func _ready():
  patterns = phases[_phase_idx].patterns
  loop_type = phases[_phase_idx].loop_type

  for i in range(phases.size()):
    for j in range(phases[i].patterns.size()):
      print_debug("Phase ", i, " Pattern ", j, ": ", phases[i].patterns[j].move_to, " - Time: ", phases[i].patterns[j].move_time)

  super._ready()

func _next_phase():
  if phases.is_empty():
    push_error("No phases defined in HarpyAI.")
    return
  
  _cancel_current_pattern()
    
  _phase_idx += 1
  if _phase_idx >= phases.size():
    print_debug("All phases completed.")
    return
  
  var phase := phases[_phase_idx]
  patterns = phase.patterns
  loop_type = phase.loop_type

  _idx = 0

  if _phase_idx == 1 and attack_core_slot and attack_core_phase1.size() > 0:
    # Phase 1 の攻撃コアをセット
    for core_scene in attack_core_phase1:
      if core_scene:
        attack_core_slot.set_core_additive(core_scene)
  elif _phase_idx == 2:
    attack_core_slot.clear_core()  # Phase 2では攻撃コアをクリア
  elif _phase_idx == 3 and attack_core_slot and attack_core_phase3_1.size() > 0:
    # Phase 3 の攻撃コアをセット
    for core_scene in attack_core_phase3_1:
      if core_scene:
        attack_core_slot.set_core_additive(core_scene)
  
  if _phase_idx == 1:
    StageSignals.emit_bgm_play_requested(_bgm, bgm_fade_in, -15)  # BGM再生リクエスト
  elif _phase_idx == 3:
    StageSignals.emit_request_hud_flash(0.3)
    StageSignals.emit_request_change_background_scroll_speed(1000, 0.3)
    StageSignals.emit_signal("sfx_play_requested", "power_up_boss", Vector2.ZERO, 0, 0)
  
  _next_pattern()

func _next_pattern():
  super._next_pattern()

  if _phase_idx == 3 and _idx % patterns.size() == 10:
    # Phase 3 の特定のパターンでは攻撃コアをセット
    print_debug("Setting attack core for Phase 3_2, Pattern Index: ", _idx)
    if attack_core_slot and attack_core_phase3_2.size() > 0:
      attack_core_slot.clear_core()  # 既存のコアをクリア
      for core_scene in attack_core_phase3_2:
        if core_scene:
          attack_core_slot.set_core_additive(core_scene)
  elif _phase_idx == 3 and _idx % patterns.size() == 0:
    # Phase 3 の最初のパターンでは攻撃コアをクリア
    if attack_core_slot and attack_core_phase3_1.size() > 0:
      attack_core_slot.clear_core()  # 既存のコアをクリア
      for core_scene in attack_core_phase3_1:
        if core_scene:
          attack_core_slot.set_core_additive(core_scene)

func _on_pattern_finished(cb_token:int):
  print_debug(_idx, " - Patterns.size(): ", patterns.size(), " - Phase Index: ", _phase_idx)
  if cb_token != _token: # 重複防止
    return
  if _idx >= patterns.size() and (_phase_idx == 0 or _phase_idx == 2):
    _next_phase()
  else:
    super._on_pattern_finished(cb_token)
