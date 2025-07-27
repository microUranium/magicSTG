extends Node

## 内部状態は完全カプセル化
var _items: Array[ItemInstance] = []


func _ready():
  # 初期化時にエフェメラルインベントリをクリア
  Ephemeralnventory.clear()

  # デバッグ用にアイテムを追加
  for i in range(10):
    var proto = ItemDb.get_item_by_id("blessing_shield")
    var item: ItemInstance = ItemInstance.new(proto)
    _items.append(item)


## ────────── API ──────────
func get_items() -> Array[ItemInstance]:
  return _items.duplicate()


func add(item: ItemInstance) -> void:
  _items.append(item)


func remove(item: ItemInstance) -> void:
  _items.erase(item)


func clear() -> void:
  _items.clear()
