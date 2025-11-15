extends Area2D
class_name Player

signal damage_received(damage)
signal game_over
signal healing_received(amount)
signal sneak_state_changed(is_sneaking: bool)
signal attack_mode_changed(rear_mode: bool)

@export var speed: float = 200.0
@export var sneak_multiplier: float = 0.5
@export var destroy_particles_scene: PackedScene = preload(
  "res://scenes/player/destroy_particle_player.tscn"
)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var blessing_container := $EquippedBlessings as BlessingContainer
@onready var hp_node := $HpNode

var player_size
var direction: Vector2
var _is_sneaking: bool = false
var _rear_mode: bool = false  # 後方攻撃モード
var _damage_flash_time: float = 0.0
var _paused: bool = false  # ポーズ状態


func _ready() -> void:
  # Set the initial animation
  animated_sprite.play("default")
  player_size = (
    animated_sprite.sprite_frames.get_frame_texture("default", 0).get_size() * animated_sprite.scale
  )
  $HpNode.connect("hp_changed", Callable(self, "_on_hp_changed"))
  self.healing_received.connect(_on_heal_received)
  TargetService.register_player(self)
  add_to_group("player_controllable")  # ポーズ管理用グループに追加


func _process(delta):
  _handle_input(delta)
  _clamp_inside_playrect()
  _update_flashing(delta)


func _update_flashing(delta):
  if !animated_sprite:
    return

  if _damage_flash_time > 0.0:
    _damage_flash_time -= delta
    animated_sprite.modulate = Color(1.0, 0.35, 0.35, animated_sprite.modulate.a)

  if _damage_flash_time <= 0.0:
    animated_sprite.modulate = Color(1.0, 1.0, 1.0, animated_sprite.modulate.a)
    _damage_flash_time = 0.0


func flash_white(duration := 0.1):
  print_debug("EnemyBase: Flashing white for ", duration, " seconds")
  _damage_flash_time = duration


func _handle_input(delta):
  if _paused:  # ポーズ中は入力を無視
    return

  direction = (
    Vector2(
      Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
      Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    )
    . normalized()
  )
  var sneaking := Input.is_action_pressed("ui_sneak")  # Shift 判定
  if sneaking != _is_sneaking:
    _is_sneaking = sneaking
    emit_signal("sneak_state_changed", _is_sneaking)

  if Input.is_action_just_pressed("ui_attack_rear"):  # Space 判定
    _rear_mode = !_rear_mode
    emit_signal("attack_mode_changed", _rear_mode)

  var effective_speed := speed * (sneak_multiplier if sneaking else 1.0)
  position += direction * effective_speed * delta


func _clamp_inside_playrect():
  var rect := PlayArea.get_play_rect()
  position.x = clamp(
    position.x, rect.position.x + player_size.x / 2, rect.end.x - player_size.x / 2
  )
  position.y = clamp(
    position.y, rect.position.y + player_size.y / 2, rect.end.y - player_size.y / 2
  )


func take_damage(amount: int) -> void:
  if _paused:  # ポーズ中はダメージを受けない
    return

  var final_damage = amount
  if blessing_container:
    final_damage = blessing_container.process_damage(self, final_damage)

  emit_signal("damage_received", final_damage)
  if final_damage > 0:
    _apply_damage(final_damage)


func _apply_damage(damage):
  $HpNode.take_damage(damage)
  StageSignals.emit_signal("sfx_play_requested", "hit_player", global_position, 0, 0)
  flash_white()


func _on_heal_received(amount: int) -> void:
  $HpNode.heal(amount)


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
  if current_hp <= 0:
    StageSignals.emit_request_change_background_scroll_speed(0, 0)  # Stop background scroll
    StageSignals.emit_request_start_vibration()  # Start vibration
    StageSignals.emit_signal("sfx_play_requested", "destroy_player", global_position, 0, 0)
    _spawn_destroy_particles()
    game_over.emit()
    queue_free()


func _spawn_destroy_particles():
  if destroy_particles_scene:
    var p: CPUParticles2D = destroy_particles_scene.instantiate()
    get_tree().current_scene.add_child(p)
    p.global_position = global_position
    p.restart()


func set_paused(paused: bool) -> void:
  """ポーズ状態を設定"""
  if _paused == paused:
    return
  _paused = paused


func _exit_tree():
  TargetService.unregister_player()
