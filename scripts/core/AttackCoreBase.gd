extends GaugeProvider
class_name AttackCoreBase

#---------------------------------------------------------------------
# Signals
#---------------------------------------------------------------------
signal core_ready_to_fire  # クールタイムが完了（撃てる）
signal core_fired  # 実際に発射した瞬間
signal core_cooldown_updated(elapsed, max)  # HUD ゲージ用

#---------------------------------------------------------------------
# Exported Properties
#---------------------------------------------------------------------
@export var cooldown_sec: float = 1.0  # 1 発ごとのクールタイム
@export var auto_start := true  # 生成直後に連射を始めるか

#---------------------------------------------------------------------
# Runtime State
#---------------------------------------------------------------------
var _cooling := false
var _paused: bool = false
var _cool_timer: SceneTreeTimer
var _owner_actor: Node2D = null  # 親ノード (Fairy / Enemy) を保持
var _proto: AttackCoreItem
var item_inst: ItemInstance:
  set(v):
    item_inst = v
    _proto = v.prototype as AttackCoreItem
    _recalc_stats()


#---------------------------------------------------------------------
# Public API
#---------------------------------------------------------------------
func trigger() -> void:
  if _paused:  # ← 停止中は撃たない
    return
  if _cooling:  # まだ冷却中
    return
  _do_fire()  # ← 派生クラスで実装
  emit_signal("core_fired")
  _start_cooldown()


func set_owner_actor(new_owner: Node) -> void:
  # 親ノード (Fairy / Enemy) を設定する
  # これにより、弾やビームが親の位置を基準に生成される
  if new_owner and new_owner is Node2D:
    _owner_actor = new_owner
  else:
    push_warning("AttackCoreBase: set_owner_actor called with invalid node type. Expected Node2D.")


#---------------------------------------------------------------------
# Virtual (override in child)
#---------------------------------------------------------------------
func _do_fire() -> void:
  # ProjectileCore / BeamCore などが弾やビームを生成する処理を書く
  pass


func _recalc_stats() -> void:
  # 共通パラメータ
  cooldown_sec = _proto.cooldown_sec_base * (1.0 - _sum_pct("cooldown_pct"))
  cooldown_sec = max(cooldown_sec, 0.02)  # 最低クールダウンは 0.02 秒
  # ここで子クラス個別の再計算も呼ぶ
  _on_stats_updated()


func _on_stats_updated() -> void:
  pass  # ProjectileCore / BeamCore が override


func _sum_pct(key: String) -> float:
  var total := 0.0
  for enc in item_inst.enchantments:
    total += enc.modifiers.get(key, 0.0)
  return total


#---------------------------------------------------------------------
# Internal
#---------------------------------------------------------------------
func _ready():
  super._ready()
  add_to_group("attack_cores")
  if auto_start:
    _start_cooldown()


func _start_cooldown():
  _cooling = true
  emit_signal("core_cooldown_updated", 0.0, cooldown_sec)
  _cool_timer = get_tree().create_timer(cooldown_sec)
  _cool_timer.timeout.connect(_on_cooldown_finished)


func _on_cooldown_finished():
  _cooling = false
  emit_signal("core_ready_to_fire")
  emit_signal("core_cooldown_updated", cooldown_sec, cooldown_sec)
  trigger()  # クールダウンが終わったら自動で発射


func set_paused(state: bool) -> void:
  if _paused == state:
    return
  _paused = state

  if _paused:
    # ---- 停止処理 ----
    if _cool_timer:
      _cool_timer = null  # これでタイマー解除
  else:
    # ---- 再開処理 ----
    _cool_timer = get_tree().create_timer(cooldown_sec)
    _cool_timer.timeout.connect(_on_cooldown_finished)


func _find_bullet_parent() -> Node:
  # 実行シーンがあればそこへ
  if get_tree().current_scene:
    return get_tree().current_scene

  # テストなどで current_scene が無いときは root へ
  return get_tree().root
