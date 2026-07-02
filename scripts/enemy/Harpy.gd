extends EnemyBase

@onready var ai: HarpyAI = $EnemyAI


func take_damage(amount: int) -> void:
  if ai._phase_idx == 0 or ai._phase_idx == 2:
    return  # Phase 0,2ではダメージを受け付けない

  super.take_damage(amount)


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  # HPバーは BossHpBar(PER_PHASE) が自己配線で表示。ここではフェーズ遷移のみ扱う。
  if ai._phase_idx == 0 or ai._phase_idx == 2:
    return  # 非戦闘フェーズ（パターン完走で遷移）

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
