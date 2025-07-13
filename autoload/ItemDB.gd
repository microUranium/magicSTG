extends Node

var _items := {}  # id → ItemBase


func _ready() -> void:
  # 起動時に Resource フォルダを自動ロード
  var dir := DirAccess.open("res://data/items")
  _scan_dir_recursive(dir)


func _scan_dir_recursive(dir: DirAccess) -> void:
  for file in dir.get_files():
    if file.get_extension() == "tres":
      var res := load(dir.get_current_dir().path_join(file))
      if res is ItemBase:
        _items[res.id] = res
  for sub in dir.get_directories():
    var sub_dir := DirAccess.open(dir.get_current_dir().path_join(sub))
    _scan_dir_recursive(sub_dir)


func get_item(id: StringName) -> ItemBase:
  return _items.get(id, null)
