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
func set_core(core_scene: PackedScene) -> void:
  # ① 既存コアを外す
  clear_core()

  # ② 新コアを生成して子に
  core = core_scene.instantiate()
  add_child(core)

  # ③ 必要なら親 (Fairy / Enemy) を渡す
  if core.has_method("set_owner_actor"):
    core.set_owner_actor(get_parent())

  emit_signal("core_changed", core)


func set_core_additive(core_scene: PackedScene) -> void:
  core = core_scene.instantiate()
  add_child(core)

  # 必要なら親 (Fairy / Enemy) を渡す
  if core.has_method("set_owner_actor"):
    core.set_owner_actor(get_parent())

  emit_signal("core_changed", core)


func clear_core() -> void:
  var cores = get_children()

  for c in cores:
    if c is AttackCoreBase:
      c.queue_free()  # コアを削除
      c = null
      emit_signal("core_cleared")
