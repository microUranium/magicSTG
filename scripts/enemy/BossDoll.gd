extends EnemyBase

@onready var ai: BossDollAI = $EnemyAI
@onready var attack_collision: CollisionShape2D = $CollisionShape_attack
var prev_position: Vector2 = Vector2.ZERO

var damage = 10


func _ready():
  super._ready()
  # 攻撃用コリジョンを初期状態で無効化
  if attack_collision:
    attack_collision.disabled = true

  connect("area_entered", Callable(self, "_on_area_entered"))


func take_damage(amount: int) -> void:
  if ai._phase_idx == 0 or ai._phase_idx == 2 or ai._phase_idx == 4 or ai._phase_idx == 7:
    return
  super.take_damage(amount)


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if current_hp <= max_hp * 0.8 and ai._phase_idx == 1:
    # HPが80%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()
  elif current_hp <= max_hp * 0.4 and ai._phase_idx == 3:
    # HPが40%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()
  elif current_hp <= max_hp * 0.05 and ai._phase_idx == 5:
    # HPが5%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()

  if current_hp <= 0:
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_request_start_vibration()  # Start vibration
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_bgm_stop_requested(1.0)  # BGM停止リクエスト
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    ai._next_phase()


func _on_area_entered(body):
  # rush状態でのみプレイヤーにダメージを与える
  if body.is_in_group("players") and animated_sprite.animation == "rush":
    body.take_damage(damage)
    print_debug("BossBird: Player hit during rush attack, damage: ", damage)


func set_parameter(_name: String, _value: String) -> void:
  await ready
  if _name == "skip_dialogue" and _value == "true":
    ai.skip_dialogue = true
  if _name == "skip_bgm_change" and _value == "true":
    ai.skip_bgm_change = true
  if _name == "skip_boss_defeat_effect" and _value == "true":
    skip_boss_defeat_effect = true
