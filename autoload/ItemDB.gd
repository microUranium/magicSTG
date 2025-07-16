extends Node

var _items := {}  # id → ItemBase
const ITEM_DIR := "res://resources/data"


func _ready():
  var tic := Time.get_ticks_msec()

  for file in DirAccess.get_files_at(ITEM_DIR):
    if not file.ends_with(".tres"):
      continue
    var res: Resource = load("%s/%s" % [ITEM_DIR, file])
    if res is ItemBase:
      _items[res.id] = res

  print("ItemDB: loaded %d items in %d ms" % [_items.size(), Time.get_ticks_msec() - tic])
