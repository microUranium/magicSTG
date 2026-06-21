extends Node
class_name BlessingContainer

const MAX_SLOTS := 3  # スロット数上限（PlayerSaveData.MAX_BLESSINGS と一致）

## 実行時に保持する加護
var blessing_instances: Array[ItemInstance] = []  # 装備中の加護アイテムインスタンス
var blessings: Array[BlessingBase] = []  # スロット順（index 0..2 = キー 1/2/3）
var _player: Node2D  # 親 Player 参照

signal blessing_equipped(blessing)
signal blessing_unequipped(blessing)


#──────────────────────────────────────────────
func _ready() -> void:
  _player = get_parent()  # = Player

  _load_blessings_from_savedata()

  for item in blessing_instances:
    if blessings.size() >= MAX_SLOTS:
      push_warning(
        "BlessingContainer: slot limit (%d) reached, ignoring extra blessings" % MAX_SLOTS
      )
      break
    if item.prototype.item_type == ItemBase.ItemType.BLESSING:
      equip_instance(item)
    else:
      push_warning("BlessingContainer: Item is not BlessingItem")


# 装備系 API -------------------------------------------------------
func equip_res(res: ItemInstanceRes) -> void:
  equip_instance(res.to_instance())


func equip_instance(inst: ItemInstance) -> void:
  if blessings.size() >= MAX_SLOTS:
    push_warning("BlessingContainer: slot limit (%d) reached" % MAX_SLOTS)
    return

  var proto := inst.prototype as BlessingItem
  if proto == null:
    push_warning("BlessingContainer: prototype is not BlessingItem")
    return

  var blessing := proto.blessing_scene.instantiate() as BlessingBase
  blessing.item_inst = inst
  add_child(blessing)

  blessing.on_equip(_player)
  blessings.append(blessing)
  emit_signal("blessing_equipped", blessing)


func unequip_all() -> void:
  for b in blessings:
    b.on_unequip(_player)
    b.queue_free()
    emit_signal("blessing_unequipped", b)
  blessings.clear()


# 被ダメージに対する介入 -----------------------------------------
func process_damage(player: Node2D, raw_damage: int) -> int:
  var final := raw_damage
  for b in blessings:
    final = b.process_damage(player, final)
  return final


# 与ダメージ（自弾→敵）に対する介入 -------------------------------
## 各加護のボーナス率を加算し、基底値に一括適用する（基底値ベースの加算合成）。
## 例: base=10, 近接+0.5, 背水+0.5 → 10 * (1 + 0.5 + 0.5) = 20
func process_outgoing_damage(enemy: Node, base_damage: int, ctx := {}) -> int:
  var bonus := 0.0
  for b in blessings:
    bonus += b.get_damage_bonus_pct(_player, enemy, ctx)
  return int(round(base_damage * (1.0 + bonus)))


# 魔法クールタイムへの介入 ---------------------------------------
## 各加護のクールタイム倍率を乗算合成する（1.0 = 等倍）。
func get_attack_cooldown_mult() -> float:
  var m := 1.0
  for b in blessings:
    m *= b.get_attack_cooldown_mult(_player)
  return m


# スロットキー入力（1/2/3）でアクティブ加護を発動 -----------------
func _unhandled_input(event: InputEvent) -> void:
  for i in range(min(MAX_SLOTS, blessings.size())):
    if event.is_action_pressed("blessing_slot_%d" % (i + 1)):
      var b := blessings[i]
      if b is ActiveBlessingBase:
        (b as ActiveBlessingBase).activate()
      get_viewport().set_input_as_handled()
      return


func _load_blessings_from_savedata() -> void:
  var equipments = PlayerSaveData.get_blessings()
  if not equipments:
    push_warning("BlessingContainer: No equipment data found.")
    return

  for item in equipments:
    if item is ItemInstance and item.prototype.item_type == ItemBase.ItemType.BLESSING:
      blessing_instances.append(item)
    else:
      push_warning("BlessingContainer: Item is not BlessingItem")
