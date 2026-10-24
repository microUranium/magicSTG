extends Node
## セーブデータファイルの読み書きを一元管理する。
## 各システム（PlayerSaveData / StageDataManager）は Dictionary との相互変換のみを担当し、
## ファイルを扱うのはこのクラスだけとする。
##
## セーブタイミング（自動セーブ）:
##   - リザルト画面の退出時（ResultInventory）
##   - 装備画面の退出時（EquipmentScreen）
## ロードはゲーム起動時に自動で行う（このノードの _ready）。
## オートロードの最後に登録し、依存する他のオートロードが初期化済みの状態でロードする。

signal saved
signal loaded

## セーブ形式を変更した場合は値を上げ、apply_save_dict で旧形式からの変換を行う
const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_data.json"
const DEFAULT_DATA_SRC := "res://resources/data/default_player_save.json"

## テストなどでセーブ先を差し替えられるよう変数にしている
var save_path := DEFAULT_SAVE_PATH


func _ready() -> void:
  load_game()


## 現在の状態をセーブファイルへ書き出す。
func save_game() -> bool:
  var f := FileAccess.open(save_path, FileAccess.WRITE)
  if f == null:
    push_error(
      (
        "SaveManager: Failed to open %s for writing (error %d)"
        % [save_path, FileAccess.get_open_error()]
      )
    )
    return false
  f.store_string(JSON.stringify(build_save_dict(), "\t"))
  f.close()
  saved.emit()
  return true


## セーブファイルを読み込む。無い・壊れている場合は初期データから開始する。
func load_game() -> void:
  var data := {}
  if FileAccess.file_exists(save_path):
    data = _read_json(save_path)
    if data.is_empty():
      push_warning("SaveManager: Corrupted save %s; fallback to default." % save_path)

  if data.is_empty() or not apply_save_dict(data):
    if not apply_save_dict(_read_json(DEFAULT_DATA_SRC)):
      push_error("SaveManager: Default save missing or invalid; starting with empty data.")
      InventoryService.clear()
      PlayerSaveData.clear_equipment()
      StageDataManager.apply_progress_dict({})

  loaded.emit()


func build_save_dict() -> Dictionary:
  var data := {"version": SAVE_VERSION, "progress": StageDataManager.get_progress_dict()}
  data.merge(PlayerSaveData.to_save_dict())
  return data


## セーブデータを各システムへ反映する。所持品・装備の形式が不正なら false を返す。
func apply_save_dict(data: Dictionary) -> bool:
  if not PlayerSaveData.load_from_dict(data):
    return false
  var progress = data.get("progress", {})
  StageDataManager.apply_progress_dict(progress if progress is Dictionary else {})
  return true


func _read_json(path: String) -> Dictionary:
  var f := FileAccess.open(path, FileAccess.READ)
  if f == null:
    return {}
  var data = JSON.parse_string(f.get_as_text())
  f.close()
  if not (data is Dictionary):
    return {}
  return data
