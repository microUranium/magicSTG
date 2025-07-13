extends Node2D

signal fairy_added(fairy)
signal fairy_removed(fairy)

@export var fairy_scene: PackedScene
@export var attack_core_scenes: Array[PackedScene] = []  # ★ プレイヤー装備中の攻撃核

@export var circle_radius := 80.0
@export var circle_rotate_speed := 180.0

@export_enum("CIRCLE", "LINE") var formation: int = 0

var fairies: Array = []  # 生成済みの精霊
var _circle_angle := 0.0


func _ready():
  _spawn_all_from_cores()  # 装備リストぶん精霊を出す


#────────────────────────────────
# Public API
#────────────────────────────────
func set_attack_cores(cores: Array[PackedScene]) -> void:
  ## 装備をまるごと入れ替えるヘルパ
  for f in fairies:
    despawn_fairy(f)
  attack_core_scenes = cores.duplicate()
  _spawn_all_from_cores()


func spawn_fairy(core_scene: PackedScene) -> Node:
  if core_scene == null:
    push_warning("FairyContainer: core_scene が null です")
    return null
  if fairy_scene == null:
    push_warning("FairyContainer: fairy_scene が未設定です")
    return null

  var f = fairy_scene.instantiate()
  add_child(f)
  fairies.append(f)

  # プレイヤー追従
  var player := get_parent()
  if player:
    f.set_player_path(player.get_path())

  # 攻撃核をセット
  var slot = f.get_node_or_null("AttackCoreSlot")
  if slot and slot.has_method("set_core"):
    slot.set_core(core_scene)

  _recalc_offset_for(f, fairies.size() - 1)
  emit_signal("fairy_added", f)
  return f


func despawn_fairy(fairy: Node) -> void:
  if fairy and fairy in fairies:
    fairies.erase(fairy)
    fairy.queue_free()
    emit_signal("fairy_removed", fairy)
    update_offsets()


func set_formation(new_form: int) -> void:
  formation = new_form
  update_offsets()


func get_fairies() -> Array:
  return fairies


#────────────────────────────────
# Internal
#────────────────────────────────


func _process(delta):
  # if formation == 0:                              # CIRCLE
  #   _circle_angle = wrapf(
  #     _circle_angle + circle_rotate_speed * delta,
  #     0.0, 360.0)
  #   update_offsets()

  pass


func _spawn_all_from_cores() -> void:
  for core_scene in attack_core_scenes:
    spawn_fairy(core_scene)


func update_offsets() -> void:
  for i in range(fairies.size()):
    _recalc_offset_for(fairies[i], i)


func _recalc_offset_for(fairy: Node, idx: int) -> void:
  var total: int = max(attack_core_scenes.size(), 1)  # 0 除算対策
  match formation:
    0:  # CIRCLE
      var base_angle := 360.0 * idx / total
      var angle_rad := deg_to_rad(base_angle + _circle_angle)
      fairy.offset = Vector2(0, -circle_radius).rotated(angle_rad)
    1:  # LINE
      fairy.offset = Vector2(30 * (idx + 1), -20)
    _:
      fairy.offset = Vector2.ZERO
