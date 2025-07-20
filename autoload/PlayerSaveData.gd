extends Node

signal equipment_changed  # 引数なし（変更検知だけ通知）
signal data_loaded  # 引数なし（ロード完了通知）

const SAVE_PATH := "user://player_save.json"
const DEFAULT_SAVE_SRC := "res://resources/data/default_player_save.json"
const MAX_ATTACK_CORES := 3  # 必要に応じて変更
const MAX_BLESSINGS := 3  # 必要に応じて変更


# ───────────────────────────────────
# 内部クラス (完全に private 扱い)
# ───────────────────────────────────
class _Equipment:
  var _attack_core: Array = []
  var _blessings: Array = []

  func copy() -> _Equipment:
    var cp := _Equipment.new()
    cp._attack_core = _attack_core.duplicate()
    cp._blessings = _blessings.duplicate()
    return cp

  ## ---------- シリアライズ ----------
  func to_dict() -> Dictionary:
    return {
      "attack_core": _attack_core.map(PlayerSaveData._serialize_item),
      "blessings": _blessings.map(PlayerSaveData._serialize_item)
    }

  static func from_dict(src: Dictionary) -> _Equipment:
    var e := _Equipment.new()

    var _to_arr = func(v):
      if v is Array:
        return v
      elif v == null:
        return []
      else:
        return [v]

    var ac_raw: Array = _to_arr.call(src.get("attack_core"))
    var bl_raw: Array = _to_arr.call(src.get("blessings"))

    e._attack_core.clear()
    for r in ac_raw:
      var inst: ItemInstance = PlayerSaveData._deserialize_item(r)
      if inst:
        e._attack_core.append(inst)

    e._blessings.clear()
    for r in bl_raw:
      var inst: ItemInstance = PlayerSaveData._deserialize_item(r)
      if inst:
        e._blessings.append(inst)

    return e


# ───────────────────────────────────
# 状態保持（private）
# ───────────────────────────────────
var _current := _Equipment.new()


# ───────────────────────────────────
# Public READ API  (UI から参照する用)
# ───────────────────────────────────
func get_attack_cores() -> Array:
  return _current._attack_core.duplicate()


func get_blessings() -> Array:
  return _current._blessings.duplicate()


func get_all_equipped_items() -> Array:
  var all_items := []
  all_items.append_array(_current._attack_core)
  all_items.append_array(_current._blessings)
  return all_items.duplicate()  # 参照渡しを避けるため


# ───────────────────────────────────
# Public WRITE / MUTATION API
# ───────────────────────────────────
func set_attack_cores(list: Array[ItemInstance]) -> void:
  _current._attack_core = list.slice(0, MAX_ATTACK_CORES)
  _after_change()


func set_blessings(list: Array[ItemInstance]) -> void:
  _current._blessings = list.duplicate()
  _after_change()


func clear_equipment() -> void:
  _current = _Equipment.new()
  _after_change()


### 「一括適用」ヘルパ（装備画面の保存ボタンで使用）
func apply_equipment(attack_cores: Array[ItemInstance], blessings: Array[ItemInstance]) -> void:
  _current._attack_core = attack_cores.slice(0, MAX_ATTACK_CORES)
  _current._blessings = blessings.duplicate()
  _after_change()


# ───────────────────────────────────
# private 共通処理
# ───────────────────────────────────
func _ready():
  _load()


func _after_change() -> void:
  _save()
  emit_signal("equipment_changed")


# ───────────── セーブ / ロード ───────────────
func _save():
  var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
  if f:
    f.store_string(JSON.stringify(_current.to_dict(), "\t"))
    f.close()


func _load():
  if FileAccess.file_exists(SAVE_PATH):
    if _try_load_from(SAVE_PATH):
      return
    push_warning("Corrupted user save; fallback to default.")
  if not _try_load_from(DEFAULT_SAVE_SRC):
    push_error("Default save missing or invalid; starting with empty data.")
    _current = _Equipment.new()
    _save()  # 空のセーブを書き出し

  emit_signal("data_loaded")  # ロード完了通知


# ------------------------------------------------
func _try_load_from(path: String) -> bool:
  var f := FileAccess.open(path, FileAccess.READ)
  if f == null:
    return false
  var data: Dictionary = JSON.parse_string(f.get_as_text())
  f.close()
  if typeof(data) != TYPE_DICTIONARY:
    push_warning("Invalid save file format; expected Dictionary, got %s." % typeof(data))
    return false

  if data.has("inventory"):
    _load_items(data)
    return true
  else:
    push_warning("Invalid save file format; missing 'inventory' key.")
    return false


# ───────── ItemInstance ⇔ JSON 変換 util ──────
static func _serialize_item(item: ItemInstance) -> Dictionary:
  if item == null:
    return {}
  return {
    "uid": item.uid,
    "id": item.prototype.id,
    "enchantments":
    item.enchantments.keys().map(func(enc): return {"id": enc.id, "level": item.enchantments[enc]})
  }


static func _deserialize_item(entry: Dictionary) -> ItemInstance:
  if entry.is_empty():
    return null
  var proto := ItemDb.get_item_by_id(entry.get("id"))
  if proto == null:
    push_warning("Unknown item id '%s' in save data." % entry.get("id"))
    return null

  var inst := ItemInstance.new(
    proto, entry.get("uid", ResourceUID.id_to_text(ResourceUID.create_id()))
  )

  if entry.has("enchantments"):
    for ench_dict in entry["enchantments"]:
      var enc := ItemDb.get_enchantment_by_id(ench_dict["id"])
      if enc:
        inst.enchantments[enc] = int(ench_dict["level"])

  return inst


func _load_items(root: Dictionary) -> void:
  var inv: Dictionary = root.get("inventory", {})
  var ac_raw: Array = inv.get("attack_core", [])
  var bl_raw: Array = inv.get("blessings", [])
  var equipped_uids: Array = root.get("equipped", {})

  # 1) 所持品を生成して InventoryService へ
  InventoryService.clear()
  var uid2inst := {}

  for e in ac_raw:
    var i := _deserialize_item(e)
    if i:
      uid2inst[i.uid] = i
      InventoryService.try_add(i)

  for e in bl_raw:
    var i := _deserialize_item(e)
    if i:
      uid2inst[i.uid] = i
      InventoryService.try_add(i)

  # 2) 装備を組み立て
  var eq := _Equipment.new()
  for uid in equipped_uids:
    if uid2inst.has(uid):
      var inst: ItemInstance = uid2inst[uid]
      if inst.prototype.item_type == ItemBase.ItemType.ATTACK_CORE:
        if eq._attack_core.size() < MAX_ATTACK_CORES:
          eq._attack_core.append(inst)
      elif inst.prototype.item_type == ItemBase.ItemType.BLESSING:
        if eq._blessings.size() < MAX_BLESSINGS:
          eq._blessings.append(inst)
    else:
      push_warning("Unknown item uid '%s' in equipped list." % uid)
  _current = eq
