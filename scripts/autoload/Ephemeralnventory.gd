extends Node

## 内部状態は完全カプセル化
var _items: Array[ItemInstance] = []


func _ready():
  # 初期化時にエフェメラルインベントリをクリア
  Ephemeralnventory.clear()


## ────────── API ──────────
func get_items() -> Array[ItemInstance]:
  return _items.duplicate()


func add(item: ItemInstance) -> void:
  _items.append(item)


func remove(item: ItemInstance) -> void:
  _items.erase(item)


func clear() -> void:
  _items.clear()
