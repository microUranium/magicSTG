extends Node
class_name BlessingContainer

## 実行時に保持する加護
var blessing_instances: Array[ItemInstance] = []  # 装備中の加護アイテムインスタンス
var blessings: Array[BlessingBase] = []
var _player: Node2D  # 親 Player 参照

signal blessing_equipped(blessing)
signal blessing_unequipped(blessing)


#──────────────────────────────────────────────
func _ready() -> void:
  _player = get_parent()  # = Player

  _load_blessings_from_savedata()

  for item in blessing_instances:
    if item.prototype.item_type == ItemBase.ItemType.BLESSING:
      equip_instance(item)
    else:
      push_warning("BlessingContainer: Item is not BlessingItem")


# 装備系 API -------------------------------------------------------
func equip_res(res: ItemInstanceRes) -> void:
  equip_instance(res.to_instance())


func equip_instance(inst: ItemInstance) -> void:
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
