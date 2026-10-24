extends Node

const INVENTORY_MAX_SIZE := 240

## 内部状態は完全カプセル化
var _items: Array[ItemInstance] = []

## ────────── Signals ──────────
signal changed  # UI・セーブ系が Listen
signal full(item: ItemInstance)  # 収納失敗時
signal equipped(item: ItemInstance)  # 装備成功時（HUD 点滅など）


## ────────── API ──────────
func get_items() -> Array[ItemInstance]:
  return _items.duplicate()


func try_add(item: ItemInstance) -> bool:
  if _items.size() >= get_max_size():
    full.emit(item)
    return false
  _items.append(item)
  changed.emit()
  return true


func remove(item: ItemInstance) -> void:
  _items.erase(item)
  changed.emit()


func clear() -> void:
  _items.clear()
  changed.emit()


func request_equip(item: ItemInstance) -> bool:
  return true


func get_max_size() -> int:
  return INVENTORY_MAX_SIZE
