extends Node

@export_file("*.tscn") var title_scene := "res://scenes/levels/title_screen.tscn"
@export_file("*.tscn") var stage_scene := "res://scenes/levels/stage_root.tscn"
@export_file("*.tscn") var equipment_scene := "res://scenes/levels/equipment_root.tscn"
@export_file("*.tscn") var result_inventory_scene := "res://scenes/levels/result_inventory.tscn"
@export_file("*.tscn") var stage_select_scene := "res://scenes/levels/stage_select.tscn"

## タイトル / 装備 / ステージ選択で共通に流すBGM
const MENU_BGM: AudioStream = preload("res://assets/audio/bgm/title_bgm.mp3")
const MENU_BGM_FADE_IN := 0
const MENU_BGM_FADE_OUT := 1.0
const MENU_BGM_VOLUME_DB := -5.0


#-------------------------------------------------
func play_menu_bgm() -> void:
  """メニュー系画面（タイトル/装備/ステージ選択）のBGMを再生する。

  既に同じBGMが鳴っている場合は再生リクエスト自体を送らないため、
  画面間のシーン切り替えでBGMが頭出しされず途切れない。"""
  if BgmController.is_playing_stream(MENU_BGM):
    return

  StageSignals.emit_bgm_play_requested(MENU_BGM, MENU_BGM_FADE_IN, MENU_BGM_VOLUME_DB)


func stop_menu_bgm() -> void:
  """メニュー系BGMをフェードアウトする。

  メニュー系BGM以外（ステージBGM等）が鳴っている場合は誤って止めないよう何もしない。"""
  if not BgmController.is_playing_stream(MENU_BGM):
    return

  StageSignals.emit_bgm_stop_requested(MENU_BGM_FADE_OUT)


#-------------------------------------------------
func change_to_title():
  get_tree().change_scene_to_file(title_scene)


func start_stage():
  # メニューを抜けるのでBGMをフェードアウト（ステージBGMはステージ側で改めて再生される）
  stop_menu_bgm()
  get_tree().change_scene_to_file(stage_scene)


func start_equipment_screen():
  get_tree().change_scene_to_file(equipment_scene)


func start_result_inventory():
  get_tree().change_scene_to_file(result_inventory_scene)


func start_stage_select_screen():
  get_tree().change_scene_to_file(stage_select_scene)

#-------------------------------------------------
