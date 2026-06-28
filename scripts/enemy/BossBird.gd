extends EnemyBase

@onready var ai: BossBirdAI = $EnemyAI
@onready var attack_collision: CollisionShape2D = $CollisionShape_attack
@onready var hp_bar = $BossHpBar
@onready var hp_node = $HpNode
var prev_position: Vector2 = Vector2.ZERO

var damage = 10


func _ready():
  super._ready()
  # 攻撃用コリジョンを初期状態で無効化
  if attack_collision:
    attack_collision.disabled = true

  # アニメーション変更を監視
  if animated_sprite:
    animated_sprite.animation_changed.connect(_on_animation_changed)
  connect("area_entered", Callable(self, "_on_area_entered"))

  # HPバーをフェーズ遷移に同期（_ready は子(EnemyAI)より後に走るため接続漏れしない）
  if hp_bar:
    ai.phase_changed.connect(_on_phase_changed)
    _on_phase_changed(ai._phase_idx)  # 初期フェーズ（会話）でバーを隠す


func take_damage(amount: int) -> void:
  if ai._phase_idx == 0:
    return  # Phase 0ではダメージを受け付けない
  super.take_damage(amount)


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  if ai._phase_idx == 0:
    return  # 会話フェーズはパターン完走で遷移するため何もしない

  var phase: PhaseResource = ai.phases[ai._phase_idx] if ai._phase_idx < ai.phases.size() else null
  var has_next_phase := ai._phase_idx < ai.phases.size() - 1

  # 現フェーズの終了HP割合を下回ったら次フェーズへ（閾値は PhaseResource.end_hp_ratio が真実の源）
  if (
    phase
    and phase.consumes_hp
    and has_next_phase
    and current_hp > 0
    and current_hp <= max_hp * phase.end_hp_ratio
  ):
    ai._next_phase()
    return

  if hp_bar:
    hp_bar.update_hp(current_hp)

  if current_hp <= 0:
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


func _on_phase_changed(phase_idx: int) -> void:
  if not hp_bar:
    return
  if phase_idx < 0 or phase_idx >= ai.phases.size():
    hp_bar.hide_bar()
    return

  var phase: PhaseResource = ai.phases[phase_idx]
  if not phase.consumes_hp:
    hp_bar.hide_bar()  # 会話/導入フェーズはバー非表示
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


func _on_animation_changed():
  # アニメーション変更時にコリジョンを制御
  if not animated_sprite or not attack_collision:
    return

  if animated_sprite.animation == "rush":
    attack_collision.disabled = false
    print_debug("BossBird: Attack collision enabled for rush animation")
  else:
    attack_collision.disabled = true
    print_debug("BossBird: Attack collision disabled for ", animated_sprite.animation, " animation")


func _process(delta: float) -> void:
  super._process(delta)
  if animated_sprite.animation == "rush":
    # 角度を移動方向に合わせる
    var direction := (global_position - prev_position).normalized()
    if direction != Vector2.ZERO:
      var rotation_angle = direction.angle() + PI / 2
      rotation = rotation_angle
    prev_position = global_position
    # サイズを1.2倍にする
    scale = Vector2(1.2, 1.2)
  elif animated_sprite.animation == "default":
    # 通常アニメーションでは角度をリセット
    rotation = 0.0
    # サイズを元に戻す
    scale = Vector2(1.0, 1.0)


func _on_area_entered(body):
  # rush状態でのみプレイヤーにダメージを与える
  print_debug("BossBird: Area entered by ", body.name)
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
