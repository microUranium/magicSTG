extends Area2D
class_name Player

signal damage_received(damage)
signal game_over

@export var speed: float = 200.0
@export var equip_blessing_scene: PackedScene
@export var destroy_particles_scene: PackedScene = preload(
  "res://scenes/player/destroy_particle_player.tscn"
)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fairy_container := $FairyContainer

var equipped_blessings = []
var player_size
var direction: Vector2


func _ready() -> void:
  # Set the initial animation
  animated_sprite.play("default")
  player_size = (
    animated_sprite.sprite_frames.get_frame_texture("default", 0).get_size() * animated_sprite.scale
  )

  if equip_blessing_scene:
    equip_blessing(equip_blessing_scene)

  $HpNode.connect("hp_changed", Callable(self, "_on_hp_changed"))


func _process(delta: float) -> void:
  # Move the player based on input
  direction = Vector2.ZERO

  if Input.is_action_pressed("ui_up"):
    direction.y -= 1
  if Input.is_action_pressed("ui_down"):
    direction.y += 1
  if Input.is_action_pressed("ui_left"):
    direction.x -= 1
  if Input.is_action_pressed("ui_right"):
    direction.x += 1

  position += direction * speed * delta

  var play_rect: Rect2 = PlayArea.get_play_rect()

  position.x = clamp(
    position.x, play_rect.position.x + player_size.x / 2, play_rect.end.x - player_size.x / 2
  )

  position.y = clamp(
    position.y, play_rect.position.y + player_size.y / 2, play_rect.end.y - player_size.y / 2
  )


func take_damage(amount: int) -> void:
  var final_damage = amount
  for blessing in equipped_blessings:
    final_damage = blessing.process_damage(self, final_damage)

  emit_signal("damage_received", final_damage)

  if final_damage > 0:
    apply_damage(final_damage)


func apply_damage(damage):
  $HpNode.take_damage(damage)
  StageSignals.emit_signal("sfx_play_requested", "hit_player", global_position, 0, 0)
  FlashUtility.flash_white(animated_sprite)
  # HP減算処理
  pass


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
  # Handle HP changes, e.g., update UI or play animations
  print("HP changed: ", current_hp, "/", max_hp)
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


func equip_blessing(blessing_scene: PackedScene):
  var blessing_instance = blessing_scene.instantiate()
  $EquippedBlessings.add_child(blessing_instance)
  blessing_instance.on_equip(self)
  equipped_blessings.append(blessing_instance)
