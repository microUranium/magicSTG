extends Node

## ゲームオーバー時に取得アイテムが破壊される確率（アイテムごとに独立判定）
const BREAK_CHANCE := 0.6

## 内部状態は完全カプセル化
var _items: Array[ItemInstance] = []
var _rng := RandomNumberGenerator.new()
var _breakage_rolled := false  # 破壊判定は clear() されるまで1回だけ


func _ready():
  _rng.randomize()
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
  _breakage_rolled = false


func roll_breakage() -> void:
  """所持アイテムそれぞれを BREAK_CHANCE の確率で破壊状態にする。

  ゲームオーバー処理が複数経路から呼ばれても破壊率が上がらないよう、
  clear() されるまでは2回目以降の呼び出しを無視する。"""
  if _breakage_rolled:
    return
  _breakage_rolled = true
  for item in _items:
    if _rng.randf() < BREAK_CHANCE:
      item.is_broken = true


func has_movable_items() -> bool:
  """破壊されていない（インベントリへ移動できる）アイテムがあるか"""
  return _items.any(func(item: ItemInstance): return not item.is_broken)


## テスト用：破壊判定の乱数シードを固定する
func set_rng_seed(seed_value: int) -> void:
  _rng.seed = seed_value
