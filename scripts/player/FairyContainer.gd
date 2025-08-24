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

  owner.connect("sneak_state_changed", Callable(self, "_on_sneak_state_changed"))
  owner.connect("game_over", Callable(self, "_on_player_game_over"))
  owner.connect("attack_mode_changed", Callable(self, "_on_change_attack_mode"))

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
  # UniversalAttackCoreで統一
  var universal_core_scene = preload("res://scenes/attackCores/universal_attack_core.tscn")
  var core = universal_core_scene.instantiate() as UniversalAttackCore

  # プレイヤーモード設定
  core.player_mode = true
  core.show_gauge_ui = true
  core.item_inst = item_inst  # AttackCoreBaseがAttackPatternを自動生成
  core.show_debug_info = true  # デバッグ用表示
  core.set_owner_actor(owner)

  # デバッグ: コア生成後のAttackPattern状態を確認
  print_debug(
    (
      "FairyContainer: Core created with pattern: %s"
      % (core.attack_pattern.resource_path.get_file() if core.attack_pattern else "none")
    )
  )

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

  update_offsets()


func update_offsets() -> void:
  # Tweenを作成
  var tw = get_tree().create_tween()

  for i in range(fairies.size()):
    var fairy = fairies[i]
    if not fairy:
      continue

    var offset = _recalc_offset_for(i)

    # Tweenを設定
    tw.tween_property(fairy, "offset", offset, 0.2)
    tw.set_parallel()
  tw.play()


func _recalc_offset_for(idx: int) -> Vector2:
  var total: int = max(attack_core_nodes.size(), 1)  # 0 除算対策
  var base_angle := 360.0 * idx / total
  var angle_rad := deg_to_rad(base_angle + _circle_angle)
  var offset = Vector2.ZERO
  match formation:
    0:  # CIRCLE
      offset = Vector2(0, -circle_radius).rotated(angle_rad)
    1:  # LINE
      offset = Vector2(circle_radius / 2 * sin(angle_rad), -circle_radius)
    _:
      return offset
  return offset


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


func _on_sneak_state_changed(is_sneaking: bool) -> void:
  set_formation(1 if is_sneaking else 0)  # スニーク時はラインフォーメーション


func _on_player_game_over() -> void:
  for fairy in fairies:
    if fairy:
      var slot = fairy.get_node_or_null("AttackCoreSlot")
      if slot:
        var cores = slot.get_active_cores()
        for core in cores:
          if core and core.has_method("cleanup_on_death"):
            core.cleanup_on_death()
      fairy.queue_free()
  fairies.clear()
  attack_core_nodes.clear()


func _on_change_attack_mode(rear_mode: bool) -> void:
  for core in attack_core_nodes:
    if core and core is UniversalAttackCore:
      (core as UniversalAttackCore).set_rear_firing_mode(rear_mode)
