extends EnemyBase

const FINAL_PHASE_IDX := 8  # 撃破演出フェーズ（phase7 の最終ラッシュ終了後に遷移してくる）

@onready var ai: BossDevilEnhancedAI = $EnemyAI
@onready var attack_collision: CollisionShape2D = $CollisionShape_attack
@export var defeat_delay: float = 0.0  # phase7 終了から撃破処理までの間（秒）
var prev_position: Vector2 = Vector2.ZERO

var damage = 10


func _ready():
  super._ready()
  StageSignals.emit_request_change_background_scroll_speed(0, 2.5)  # スクロール速度を0に
  # 撃破はダメージではなくフェーズ遷移で駆動する（FINAL_PHASE_IDX 到達＝自動撃破）
  ai.phase_changed.connect(_on_ai_phase_changed)


func take_damage(amount: int) -> void:
  if ai._phase_idx == 0 or ai._phase_idx == 2 or ai._phase_idx == 4 or ai._phase_idx >= 6:
    return  # 会話フェーズと最終ラッシュ〜撃破演出ではダメージを受け付けない
  super.take_damage(amount)


func _on_ai_phase_changed(phase_idx: int) -> void:
  if phase_idx == FINAL_PHASE_IDX:
    _defeat_boss()


func _defeat_boss() -> void:
  if not mark_dead_once():  # 撃破処理の多重実行を防ぐ
    return

  if defeat_delay > 0.0:
    await get_tree().create_timer(defeat_delay, false).timeout
    if not is_instance_valid(self):
      return

  if not skip_boss_defeat_effect:
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_request_start_vibration()  # Start vibration
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_bgm_stop_requested(1.0)  # BGM停止リクエスト
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
  _spawn_destroy_particles()
  queue_free()


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if current_hp <= max_hp * 0.9 and ai._phase_idx == 1:
    # Phase 1でHPが95%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()
  elif current_hp <= max_hp * 0.6 and ai._phase_idx == 3:
    # Phase 3でHPが90%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()
  elif current_hp <= max_hp * 0.1 and ai._phase_idx == 5:
    # Phase 5でHPが10%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()


func _process(delta: float) -> void:
  super._process(delta)

  if ai._phase_idx == 7:
    var player_node = TargetService.get_player()
    if player_node:
      # プレイヤーを自身に引き寄せる
      var direction_to_player = (global_position - player_node.global_position).normalized()
      var pull_strength = 75.0  # 引き寄せの強さ
      player_node.global_position += direction_to_player * pull_strength * delta


func set_parameter(_name: String, _value: String) -> void:
  await ready
  if _name == "skip_dialogue" and _value == "true":
    ai.skip_dialogue = true
  if _name == "skip_bgm_change" and _value == "true":
    ai.skip_bgm_change = true
  if _name == "skip_boss_defeat_effect" and _value == "true":
    skip_boss_defeat_effect = true
