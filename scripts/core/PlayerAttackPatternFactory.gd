extends RefCounted
class_name PlayerAttackPatternFactory

# プレイヤー用AttackPatternをItemInstanceから動的生成するファクトリー


static func create_pattern_from_item_instance(item_inst: ItemInstance) -> AttackPattern:
  """ItemInstanceからプレイヤー用AttackPatternを生成"""
  if not item_inst.prototype is AttackCoreItem:
    push_error("PlayerAttackPatternFactory: ItemInstance does not contain AttackCoreItem.")
    return null

  var attack_core_item = item_inst.prototype as AttackCoreItem
  var pattern = AttackPattern.new()
  if not attack_core_item.attack_pattern:
    # コアタイプによってパターンタイプを決定
    _determine_pattern_type(pattern, attack_core_item)

    # プレイヤー用のデフォルト設定
    pattern.target_group = "enemies"
    pattern.bullet_count = 1
    pattern.direction_type = AttackPattern.DirectionType.FIXED
    pattern.base_direction = Vector2.UP
  else:
    # 既存のパターンを使用
    pattern = attack_core_item.attack_pattern.duplicate() as AttackPattern

  # 基本設定をAttackCoreItemから取得
  if attack_core_item.damage_base > 0:
    pattern.damage = attack_core_item.damage_base

  if attack_core_item.cooldown_sec_base > 0:
    pattern.burst_delay = attack_core_item.cooldown_sec_base

  # 弾丸シーンの設定
  if attack_core_item.projectile_scene:
    pattern.bullet_scene = attack_core_item.projectile_scene

  # 基本修正値から弾速を取得
  var base_speed = attack_core_item.base_modifiers.get("bullet_speed", 400.0)
  pattern.bullet_speed = base_speed

  return pattern


static func _determine_pattern_type(
  pattern: AttackPattern, attack_core_item: AttackCoreItem
) -> void:
  """AttackCoreItemのcore_sceneからパターンタイプを決定"""
  if not attack_core_item.core_scene:
    return

  # BeamCoreの場合
  if attack_core_item.pattern_type == AttackCoreItem.PatternType.BEAM:
    pattern.pattern_type = AttackPattern.PatternType.BEAM
    pattern.beam_scene = attack_core_item.projectile_scene
    pattern.beam_duration = 2.0
    pattern.continuous_damage = true
  # ProjectileCoreや他の場合
  else:
    pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT


static func update_pattern_from_enchantments(
  pattern: AttackPattern, item_inst: ItemInstance
) -> void:
  """エンチャントによるパターンの動的更新（必要に応じて）"""
  if not item_inst.prototype is AttackCoreItem:
    push_error("PlayerAttackPatternFactory: ItemInstance does not contain AttackCoreItem.")

  # ダメージの更新
  pattern.damage = int(
    _apply_enchantment_modifiers(item_inst, item_inst.prototype.damage_base, "damage")
  )

  # 弾速の更新
  var base_speed = item_inst.prototype.base_modifiers.get("bullet_speed", 400.0)
  pattern.bullet_speed = _apply_enchantment_modifiers(item_inst, base_speed, "bullet_speed")

  # 残留時間の更新
  var base_lifetime = pattern.bullet_lifetime
  if base_lifetime > 0:
    pattern.bullet_lifetime = _apply_enchantment_modifiers(
      item_inst, base_lifetime, "bullet_lifetime"
    )
  else:
    pattern.bullet_lifetime = 0.0  # デフォルトは無限

  # クールダウン時間の更新
  var cooldown_sec = _apply_enchantment_modifiers(
    item_inst, item_inst.prototype.cooldown_sec_base, "cooldown"
  )
  cooldown_sec = max(cooldown_sec, 0.02)  # 最低クールダウンは 0.02 秒
  pattern.burst_delay = cooldown_sec


static func _apply_enchantment_modifiers(
  item_inst: ItemInstance, base_value: float, modifier_key: String
) -> float:
  return (
    base_value * (1.0 + _sum_enchant_modifier(item_inst, modifier_key + "_pct"))
    + _sum_enchant_modifier(item_inst, modifier_key + "_add")
  )


static func _sum_enchant_modifier(item_inst: ItemInstance, key: String) -> float:
  var total := 0.0
  if not item_inst:
    return total
  for enc in item_inst.enchantments:
    var modifiers: Dictionary = enc.get_modifiers(item_inst.enchantments[enc])
    total += modifiers.get(key, 0.0)
  return total
