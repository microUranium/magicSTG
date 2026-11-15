extends EnemyBase

const PHASE_CHANGE_HP_RATIO := 0.5  # フェーズ1で HP がこの割合以下になると次のフェーズへ

@onready var ai: BossBearAI = $EnemyAI
@onready var attack_collision: CollisionShape2D = $CollisionShape_attack
var prev_position: Vector2 = Vector2.ZERO
var _second_form_reached := false  # 第2形態（フェーズ2）に一度でも入ったか

var damage = 10


func _ready():
  super._ready()
  # 攻撃用コリジョンを初期状態で無効化
  if attack_collision:
    attack_collision.disabled = true

  connect("area_entered", Callable(self, "_on_area_entered"))
  ai.phase_changed.connect(_on_ai_phase_changed)

  # 登場〜会話の間は眠っている演出のためアニメーションを止めておく
  # （会話後に BossBearAI.start_boss_animation() で動き出す）
  if animated_sprite:
    animated_sprite.stop()
    animated_sprite.frame = 0


func take_damage(amount: int) -> void:
  if ai._phase_idx == 0:
    return  # Phase 0ではダメージを受け付けない
  super.take_damage(amount)


func _on_ai_phase_changed(phase_idx: int) -> void:
  if phase_idx >= 2:
    _second_form_reached = true


func get_burst_hp_floor() -> int:
  # 第2形態に一度入るまでは、その境目より下に減らさない。
  # クマはフェーズ1と2を行き来するうえ、HP が境目を下回ってから実際に第2形態へ移るまで
  # 間があるため、フェーズ番号ではなく「第2形態に入ったか」で判定する
  if not _second_form_reached:
    return hp_threshold(PHASE_CHANGE_HP_RATIO)
  return 0


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if current_hp <= max_hp * PHASE_CHANGE_HP_RATIO and not ai.get_phase_changable():
    # Phase 1でHPが50%以下になったら次のフェーズへ
    ai.enable_phase_change()
  elif current_hp <= 0:
    if not mark_dead_once():  # 同一フレームでの多重被弾による撃破処理の重複を防ぐ
      return
    if !skip_boss_defeat_effect:
      StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
      StageSignals.emit_request_change_background_scroll_speed(0, 2.5)  # スクロール速度を0に
      StageSignals.emit_request_start_vibration()  # Start vibration
      StageSignals.emit_bgm_stop_requested(1.0)  # BGM停止リクエスト
      StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    else:
      StageSignals.emit_signal("sfx_play_requested", "destroy_enemy", global_position, 0, 0)
    StageSignals.emit_destroy_bullet()
    _spawn_destroy_particles()
    _drop_item()  # 中ボスはドロップする（章ボスの報酬は別経路で扱う）
    queue_free()


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
