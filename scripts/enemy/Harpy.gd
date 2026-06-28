extends EnemyBase

@onready var ai: HarpyAI = $EnemyAI
@onready var hp_bar = $BossHpBar
@onready var hp_node = $HpNode


func _ready():
  super._ready()
  # HPバーをフェーズ遷移に同期（_ready は子(EnemyAI)より後に走るため接続漏れしない）
  if hp_bar:
    ai.phase_changed.connect(_on_phase_changed)
    _on_phase_changed(ai._phase_idx)  # 初期フェーズ（会話）でバーを隠す


func take_damage(amount: int) -> void:
  if ai._phase_idx == 0 or ai._phase_idx == 2:
    return  # Phase 0,2ではダメージを受け付けない

  super.take_damage(amount)


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if ai._phase_idx == 0 or ai._phase_idx == 2:
    return  # 非戦闘フェーズ（パターン完走で遷移）。バーは _on_phase_changed が制御

  if hp_bar:
    hp_bar.update_hp(current_hp)

  var phase: PhaseResource = ai.phases[ai._phase_idx] if ai._phase_idx < ai.phases.size() else null

  if ai._phase_idx == 1 and phase and current_hp > 0 and current_hp <= max_hp * phase.end_hp_ratio:
    # Phase 1で終了HP割合（既定50%）以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()
  elif current_hp <= 0:
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_request_change_background_scroll_speed(0, 2.5)  # スクロール速度を0に
    StageSignals.emit_request_start_vibration()  # Start vibration
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_bgm_stop_requested(1.0)  # BGM停止リクエスト
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    _spawn_destroy_particles()
    queue_free()


func _on_phase_changed(phase_idx: int) -> void:
  if not hp_bar:
    return
  if phase_idx < 0 or phase_idx >= ai.phases.size():
    hp_bar.hide_bar()
    return

  var phase: PhaseResource = ai.phases[phase_idx]
  if not phase.consumes_hp:
    hp_bar.hide_bar()  # 会話/攻撃停止フェーズはバー非表示
    return

  # このフェーズのHP区間 [low, high] を算出
  #   high = 直前の戦闘フェーズの end_hp_ratio（無ければ満タン 1.0）
  #   low  = このフェーズの end_hp_ratio
  var max_hp: int = hp_node.max_hp
  var high_ratio := 1.0
  for i in range(phase_idx - 1, -1, -1):
    if ai.phases[i].consumes_hp:
      high_ratio = ai.phases[i].end_hp_ratio
      break
  var high_hp := int(round(max_hp * high_ratio))
  var low_hp := int(round(max_hp * phase.end_hp_ratio))

  hp_bar.begin_phase(low_hp, high_hp, hp_node.current_hp)
