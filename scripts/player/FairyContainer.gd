extends Node2D

signal fairy_added(fairy)
signal fairy_removed(fairy)

@export var fairy_scene: PackedScene
@export var circle_radius := 80.0
@export var circle_rotate_speed := 180.0

@export_enum("CIRCLE", "LINE") var formation: int = 0

var attack_core_instance: Array[ItemInstance] = []  # ★ 装備中の攻撃核インスタンス
var attack_core_nodes: Array[AttackCoreBase] = []  # ★ プレイヤー装備中の攻撃核
var fairies: Array = []  # 生成済みの精霊
var _circle_angle := 0.0


func _ready():
  _load_attack_core_from_savedata()

  # アイテムインスタンスから攻撃核を取得
  for inst in attack_core_instance:
    if inst.prototype is AttackCoreItem:
      var core: AttackCoreBase = equip_core(inst)
      if core:
        attack_core_nodes.append(core)

  if attack_core_nodes.size() == 0:
    push_error("FairyContainer: No attack cores found in the equipped items.")

  _spawn_all_from_cores()  # 装備リストぶん精霊を出す


#────────────────────────────────
# Public API
#────────────────────────────────
func set_attack_cores(cores: Array[AttackCoreBase]) -> void:
  ## 装備をまるごと入れ替えるヘルパ
  for f in fairies:
    despawn_fairy(f)
  attack_core_nodes = cores.duplicate()
  _spawn_all_from_cores()


func equip_core(item_inst: ItemInstance) -> AttackCoreBase:
  var proto := item_inst.prototype as AttackCoreItem
  var core := proto.core_scene.instantiate() as AttackCoreBase
  core.item_inst = item_inst  # ★ 注入
  core.set_owner_actor(owner)
  return core


func spawn_fairy(core_node: AttackCoreBase) -> Node:
  if core_node == null:
    push_warning("FairyContainer: core_node が null です")
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
    slot.set_core(core_node)

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
  for core_scene in attack_core_nodes:
    spawn_fairy(core_scene)


func update_offsets() -> void:
  for i in range(fairies.size()):
    _recalc_offset_for(fairies[i], i)


func _recalc_offset_for(fairy: Node, idx: int) -> void:
  var total: int = max(attack_core_nodes.size(), 1)  # 0 除算対策
  match formation:
    0:  # CIRCLE
      var base_angle := 360.0 * idx / total
      var angle_rad := deg_to_rad(base_angle + _circle_angle)
      fairy.offset = Vector2(0, -circle_radius).rotated(angle_rad)
    1:  # LINE
      fairy.offset = Vector2(30 * (idx + 1), -20)
    _:
      fairy.offset = Vector2.ZERO


func _load_attack_core_from_savedata() -> void:
  var equipments = PlayerSaveData.get_attack_cores()
  if not equipments:
    push_warning("FairyContainer: No equipment data found.")
    return

  for item in equipments:
    if item is ItemInstance and item.prototype.item_type == ItemBase.ItemType.ATTACK_CORE:
      attack_core_instance.append(item)
    else:
      push_warning("FairyContainer: Invalid item instance in savedata.")
