extends EnemyBase

@onready var ai: BossRobeAI = $EnemyAI
@onready var attack_collision: CollisionShape2D = $CollisionShape_attack
var prev_position: Vector2 = Vector2.ZERO


func _ready():
  super._ready()


func take_damage(amount: int) -> void:
  if ai._phase_idx == 0:
    return  # Phase 0ではダメージを受け付けない
  $HpNode.take_damage(amount)
  StageSignals.emit_signal("sfx_play_requested", "hit_enemy", global_position, 0, 0)
  FlashUtility.flash_white(animated_sprite)


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  if current_hp <= max_hp * 0.5 and ai._phase_idx == 1:
    # Phase 1でHPが50%以下になったら次のフェーズへ
    ai._next_phase()
  elif current_hp <= 0:
    if !skip_boss_defeat_effect:
      StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
      StageSignals.emit_request_change_background_scroll_speed(0, 2.5)  # スクロール速度を0に
      StageSignals.emit_request_start_vibration()  # Start vibration
      StageSignals.emit_destroy_bullet()  # Destroy bullet
      StageSignals.emit_bgm_stop_requested(1.0)  # BGM停止リクエスト
      StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    else:
      StageSignals.emit_signal("sfx_play_requested", "destroy_enemy", global_position, 0, 0)
    _spawn_destroy_particles()
    queue_free()

  if ai._phase_idx == 3:
    # Phase 3でHPが30%以下になったらクローンの透明度を変化
    var alpha = current_hp as float / (max_hp * 0.3)
    ai.change_clones_alpha(clamp(1 - alpha, 0.0, 1.0))


func set_parameter(_name: String, _value: String) -> void:
  await ready
  if _name == "skip_dialogue" and _value == "true":
    ai.skip_dialogue = true
  if _name == "skip_bgm_change" and _value == "true":
    ai.skip_bgm_change = true
  if _name == "skip_boss_defeat_effect" and _value == "true":
    skip_boss_defeat_effect = true
