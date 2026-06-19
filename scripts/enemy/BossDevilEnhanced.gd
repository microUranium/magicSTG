extends EnemyBase

@onready var ai: BossDevilEnhancedAI = $EnemyAI
@onready var attack_collision: CollisionShape2D = $CollisionShape_attack
var prev_position: Vector2 = Vector2.ZERO

var damage = 10


func _ready():
  super._ready()
  StageSignals.emit_request_change_background_scroll_speed(0, 2.5)  # スクロール速度を0に


func take_damage(amount: int) -> void:
  if (
    ai._phase_idx == 0
    or ai._phase_idx == 2
    or ai._phase_idx == 4
    or ai._phase_idx == 6
    or ai._phase_idx == 7
  ):
    return  # Phase 0ではダメージを受け付けない
  super.take_damage(amount)


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
  elif ai._phase_idx == 8:
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_request_start_vibration()  # Start vibration
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_bgm_stop_requested(1.0)  # BGM停止リクエスト
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    _spawn_destroy_particles()
    queue_free()


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
