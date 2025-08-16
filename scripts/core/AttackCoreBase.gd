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
@export var attack_pattern: AttackPattern:
  set = set_attack_pattern
@export var player_mode: bool = false
@export var show_gauge_ui: bool = false

#---------------------------------------------------------------------
# Runtime State
#---------------------------------------------------------------------
var _cooling: bool = false
var _paused: bool = false
var _cool_timer: SceneTreeTimer
var _owner_actor: Node2D = null  # 親ノード (Fairy / Enemy) を保持
var _proto: AttackCoreItem
var _last_fire_success: bool = false
var item_inst: ItemInstance:
  set(v):
    item_inst = v
    _proto = v.prototype as AttackCoreItem
    _update_attack_pattern_stats()


#---------------------------------------------------------------------
# AttackPattern 管理
#---------------------------------------------------------------------
func set_attack_pattern(new_pattern: AttackPattern) -> void:
  """攻撃パターンを設定"""
  var old_pattern = attack_pattern
  attack_pattern = new_pattern

  # パターン変更時の処理
  _on_pattern_changed(old_pattern, new_pattern)

  if old_pattern != new_pattern:
    emit_signal("pattern_changed", new_pattern)


func _on_pattern_changed(old_pattern: AttackPattern, new_pattern: AttackPattern) -> void:
  """パターン変更時の共通処理"""
  # クールダウンタイムをパターンから更新
  if new_pattern and new_pattern.burst_delay > 0:
    cooldown_sec = new_pattern.burst_delay

  # 自動発射設定をパターンから更新
  if new_pattern:
    auto_start = new_pattern.auto_start

    # 子クラスでの追加処理
  _on_pattern_changed_impl(old_pattern, new_pattern)


func _on_pattern_changed_impl(old_pattern: AttackPattern, new_pattern: AttackPattern) -> void:
  """子クラスでオーバーライドするパターン変更処理"""
  pass


#---------------------------------------------------------------------
# Public API
#---------------------------------------------------------------------
func trigger() -> void:
  if not can_fire():
    return
  var success = await _do_fire()

  if success:
    emit_signal("core_fired")
    _start_cooldown()


func force_fire() -> void:
  """強制発射（クールダウン無視）"""
  if _paused:
    return

  var success = await _do_fire()

  if success:
    emit_signal("core_fired")


func can_fire() -> bool:
  """発射可能かチェック"""
  return not _paused and not _cooling


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
func _do_fire() -> bool:
  # ProjectileCore / BeamCore などが弾やビームを生成する処理を書く
  await get_tree().process_frame  # 最低限のawait
  _last_fire_success = false
  push_warning("AttackCoreBase: _do_fire() is not implemented in child class.")
  return false


#---------------------------------------------------------------------
# Internal
#---------------------------------------------------------------------
func _ready():
  show_on_hud = player_mode and show_gauge_ui
  super._ready()
  add_to_group("attack_cores")

  # プレイヤーモード時にAttackPatternを動的生成
  if player_mode and item_inst and not attack_pattern:
    _generate_attack_pattern_from_item()
    _update_attack_pattern_stats()
    init_gauge("cooldown", 100, 0, _proto.display_name)

  # パターンの初期検証
  _validate_pattern()
  if auto_start:
    _start_cooldown()


func _validate_pattern():
  """パターンの有効性を検証"""
  if not attack_pattern:
    push_warning("AttackCoreBase: No attack pattern assigned.")
    return

  match attack_pattern.pattern_type:
    AttackPattern.PatternType.BEAM:
      if not attack_pattern.beam_scene:
        push_warning("AttackCoreBase: Beam pattern has no beam scene.")
    _:
      if not attack_pattern.bullet_scene:
        push_warning("AttackCoreBase: Attack pattern has no bullet scene.")


func _validate_enchantments() -> bool:
  """装着エンチャントの互換性チェック"""
  if not item_inst:
    return true
  var available_keys = _get_available_enchant_keys()
  for enc in item_inst.enchantments:
    var modifiers = enc.get_modifiers(item_inst.enchantments[enc])
    for key in modifiers.keys():
      if not _is_compatible_enchant_key(key, available_keys):
        push_warning("Incompatible enchantment: %s" % key)
        return false
  return true


func _get_available_enchant_keys() -> Array[String]:
  """このコアが対応するエンチャントキーを返す"""
  return ["damage", "bullet_speed", "cooldown"]


func _is_compatible_enchant_key(key: String, available_keys: Array[String]) -> bool:
  """エンチャントキーが対応しているかチェック"""
  return key in available_keys


func _generate_attack_pattern_from_item() -> void:
  """ItemInstanceからAttackPatternを動的生成"""
  if not item_inst or not _proto:
    return

  attack_pattern = PlayerAttackPatternFactory.create_pattern_from_item_instance(item_inst)
  if attack_pattern:
    print_debug("AttackCoreBase: Generated attack pattern from item: %s" % _proto.display_name)
  else:
    push_warning("AttackCoreBase: Failed to generate attack pattern from item.")


func _update_attack_pattern_stats() -> void:
  """エンチャント適用後にAttackPatternの値を更新"""
  if player_mode and item_inst and attack_pattern:
    PlayerAttackPatternFactory.update_pattern_from_enchantments(attack_pattern, item_inst)
    set_attack_pattern(attack_pattern)  # パターンを更新
    print_debug("AttackCoreBase: Updated attack pattern stats from item: %s" % _proto.display_name)
  else:
    push_warning(
      "AttackCoreBase: Cannot update attack pattern stats, item_inst or attack_pattern is missing."
    )


func _start_cooldown():
  _cooling = true
  emit_signal("core_cooldown_updated", 0.0, cooldown_sec)
  if _cool_timer:
    _cool_timer.timeout.disconnect(_on_cooldown_finished)
    _cool_timer = null
  _cool_timer = get_tree().create_timer(cooldown_sec)
  _cool_timer.timeout.connect(_on_cooldown_finished)


func _on_cooldown_finished():
  _cooling = false
  emit_signal("core_ready_to_fire")
  emit_signal("core_cooldown_updated", cooldown_sec, cooldown_sec)
  trigger()


func set_paused(state: bool) -> void:
  if _paused == state:
    return
  _paused = state

  if _paused:
    if _cool_timer:
      _cool_timer.timeout.disconnect(_on_cooldown_finished)
      _cool_timer = null
  elif auto_start:
    _start_cooldown()


func _find_bullet_parent() -> Node:
  # サービスロケーターから取得を試行
  var bullet_parent = TargetService.get_bullet_parent()
  if bullet_parent:
    return bullet_parent

  # フォールバック: 実行シーンがあればそこへ
  if get_tree().current_scene:
    return get_tree().current_scene

  # テストなどで current_scene が無いときは root へ
  return get_tree().root


func _get_last_fire_success() -> bool:
  """最後の発射が成功したかを取得（テスト用）"""
  return _last_fire_success


func get_debug_info() -> Dictionary:
  """デバッグ情報を取得"""
  return {
    "class_name": get_class(),
    "cooling": _cooling,
    "paused": _paused,
    "cooldown_sec": cooldown_sec,
    "pattern_name": attack_pattern.resource_path.get_file() if attack_pattern else "none",
    "owner": str(_owner_actor.name) if _owner_actor else "none",
    "can_fire": can_fire()
  }
