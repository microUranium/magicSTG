extends Node
class_name AttackCoreSlot  # 他スクリプトから型補完しやすくする

signal core_changed(new_core)
signal core_cleared

@export var default_core_scene: PackedScene  # インスペクタでデフォルト指定も可
var core: AttackCoreBase = null  # 現在のコア参照（なければ null）


func _ready() -> void:
  if default_core_scene and core == null:
    set_core(default_core_scene)


#-------------------------------------------------
# Public API
#-------------------------------------------------
func set_core(core_input) -> void:
  clear_core()

  if core_input is PackedScene:
    core = core_input.instantiate()
  elif core_input is AttackCoreBase:
    core = core_input
  else:
    push_error("AttackCoreSlot: Invalid core input type. Expected PackedScene or AttackCoreBase.")
    return

  add_child(core)

  # 必要なら親 (Fairy / Enemy) を渡す
  if core.has_method("set_owner_actor"):
    core.set_owner_actor(get_parent())

  emit_signal("core_changed", core)


func set_core_additive(core_input) -> void:
  var new_core: AttackCoreBase = null

  if core_input is PackedScene:
    new_core = core_input.instantiate()
  elif core_input is AttackCoreBase:
    new_core = core_input
  else:
    push_warning("AttackCoreSlot: Unsupported core_input type.")
    return

  add_child(new_core)

  if new_core.has_method("set_owner_actor"):
    new_core.set_owner_actor(get_parent())

  emit_signal("core_changed", new_core)


func clear_core() -> void:
  var cores = get_children()

  for c in cores:
    if c is AttackCoreBase:
      c.queue_free()  # コアを削除
      c = null
      emit_signal("core_cleared")
