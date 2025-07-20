extends Node

var _items := {}  # id → ItemBase
var _enchantments := {}  # id → Enchantment
const ITEM_DIR := "res://resources/data"


func _ready():
  var tic := Time.get_ticks_msec()

  for file in DirAccess.get_files_at(ITEM_DIR):
    if not file.ends_with(".tres"):
      continue
    var res: Resource = load("%s/%s" % [ITEM_DIR, file])
    if res is ItemBase:
      _items[res.id] = res
    elif res is Enchantment:
      _enchantments[res.id] = res

  print("ItemDB: loaded %d items in %d ms" % [_items.size(), Time.get_ticks_msec() - tic])


func get_item_by_id(id: String) -> ItemBase:
  if _items.has(id):
    return _items[id]
  else:
    push_error("ItemDB: Item with id '%s' not found." % id)
    return null


func get_enchantment_by_id(id: String) -> Enchantment:
  if _enchantments.has(id):
    return _enchantments[id]
  else:
    push_error("ItemDB: Enchantment with id '%s' not found." % id)
    return null
