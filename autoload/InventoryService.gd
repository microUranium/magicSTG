extends Node

const max_size := 100

## 内部状態は完全カプセル化
var _items: Array[ItemInstance] = []

## ────────── Signals ──────────
signal changed                       # UI・セーブ系が Listen
signal full(item: ItemInstance)      # 収納失敗時
signal equipped(item: ItemInstance)  # 装備成功時（HUD 点滅など）

## ────────── API ──────────
func get_items() -> Array[ItemInstance]:
  return _items.duplicate()

func try_add(item: ItemInstance) -> bool:
  if _items.size() >= max_size:
    full.emit(item)
    return false
  _items.append(item)
  print_debug("Item added: ", item.prototype.display_name)
  print_debug("Current inventory size: ", _items.size())
  var enchantments = item.enchantments
  if enchantments.size() > 0:
    print_debug("Enchantments: ", enchantments[0].display_name, "x", enchantments[0].modifiers["level"])
  changed.emit()
  return true

func remove(item: ItemInstance) -> void:
  _items.erase(item)
  changed.emit()

func request_equip(item: ItemInstance) -> bool:
  return true