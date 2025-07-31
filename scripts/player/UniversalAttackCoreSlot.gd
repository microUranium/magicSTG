extends Node
class_name UniversalAttackCoreSlot

signal core_changed(new_core)
signal core_cleared
signal pattern_changed(new_pattern)

@export var default_core_scene: PackedScene
@export var attack_pattern: AttackPattern:
  set = set_attack_pattern
@export var auto_create_core: bool = true

var _cores: Array[AttackCoreBase] = []  # 複数コア対応
var _pattern_update_pending: bool = false


func _ready() -> void:
  if auto_create_core and default_core_scene and _cores.is_empty():
    set_core(default_core_scene)


# === パターン設定の改善 ===


func set_attack_pattern(new_pattern: AttackPattern) -> void:
  """攻撃パターンを設定（既存コアに即座に反映）"""
  var old_pattern = attack_pattern
  attack_pattern = new_pattern

  # 既存のコアに新しいパターンを適用
  _apply_pattern_to_all_cores()

  if old_pattern != new_pattern:
    emit_signal("pattern_changed", new_pattern)


func _apply_pattern_to_all_cores() -> void:
  """全てのコアに現在のパターンを適用"""
  for core in _cores:
    if core and is_instance_valid(core):
      #if core.has_property("attack_pattern"):
      core.attack_pattern = attack_pattern


# === コア管理の改善 ===


func set_core(core_input) -> void:
  """単一コアを設定（既存コアをクリア）"""
  clear_all_cores()
  add_core(core_input)


func add_core(core_input) -> AttackCoreBase:
  """コアを追加（既存コアは保持）"""
  var new_core: AttackCoreBase = _create_core_from_input(core_input)
  if not new_core:
    return null

  _cores.append(new_core)
  add_child(new_core)

  _setup_core(new_core)

  emit_signal("core_changed", new_core)
  return new_core


func _create_core_from_input(core_input) -> AttackCoreBase:
  """入力からコアインスタンスを作成"""
  if core_input is PackedScene:
    var instance = core_input.instantiate()
    if instance is AttackCoreBase:
      return instance
    else:
      push_error("AttackCoreSlot: Scene does not contain AttackCoreBase.")
      instance.queue_free()
      return null
  elif core_input is AttackCoreBase:
    return core_input
  else:
    push_error("AttackCoreSlot: Invalid core input type. Expected PackedScene or AttackCoreBase.")
    return null


func _setup_core(core: AttackCoreBase) -> void:
  """コアの初期設定"""
  # 攻撃パターンを設定（コアが既にパターンを持っていない場合のみ）
  if not core.attack_pattern and attack_pattern:
    core.attack_pattern = attack_pattern

  # オーナーを設定
  if core.has_method("set_owner_actor"):
    core.set_owner_actor(get_parent())


# === コア削除の改善 ===


func remove_core(core: AttackCoreBase) -> bool:
  """特定のコアを削除"""
  var index = _cores.find(core)
  if index == -1:
    return false
  _cores.remove_at(index)
  if is_instance_valid(core):
    core.queue_free()
  emit_signal("core_cleared")
  return true


func clear_all_cores() -> void:
  """全てのコアを削除"""
  for core in _cores:
    if is_instance_valid(core):
      core.queue_free()
  _cores.clear()
  emit_signal("core_cleared")


# === 便利メソッドの追加 ===


func get_active_cores() -> Array[AttackCoreBase]:
  """有効なコアのリストを取得"""
  var active_cores: Array[AttackCoreBase] = []
  for core in _cores:
    if is_instance_valid(core):
      active_cores.append(core)
  return active_cores


func get_core_count() -> int:
  """アクティブなコアの数を取得"""
  return get_active_cores().size()


func has_cores() -> bool:
  """コアが存在するかチェック"""
  return get_core_count() > 0


func pause_all_cores(paused: bool) -> void:
  """全てのコアの一時停止/再開"""
  for core in get_active_cores():
    if core.has_method("set_paused"):
      core.set_paused(paused)


func trigger_all_cores() -> void:
  """全てのコアを強制発動"""
  for core in get_active_cores():
    if core.has_method("force_fire"):
      core.force_fire()


# === デバッグ支援メソッド ===


func get_debug_info() -> Dictionary:
  """デバッグ情報を取得"""
  return {
    "core_count": get_core_count(),
    "pattern_name": attack_pattern.resource_path.get_file() if attack_pattern else "none",
    "cores":
    _cores.map(func(core): return core.get_class() if is_instance_valid(core) else "invalid")
  }


# === エラーハンドリングの改善 ===


func _validate_state() -> bool:
  """内部状態の整合性をチェック"""
  var valid_cores = get_active_cores()
  if valid_cores.size() != _cores.size():
    push_warning("AttackCoreSlot: Detected invalid cores in array. Cleaning up.")
    _cores = valid_cores
    return false
  return true


func _notification(what):
  match what:
    NOTIFICATION_PREDELETE:
      clear_all_cores()


# === パフォーマンス最適化 ===


# GDScript の配列操作を最適化
func _optimized_core_cleanup():
  """無効なコアを効率的に削除"""
  for i in range(_cores.size() - 1, -1, -1):
    if not is_instance_valid(_cores[i]):
      _cores.remove_at(i)
