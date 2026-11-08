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

## シーン遷移時の画面フェード（秒）
const SceneTransitionScript := preload("res://scripts/ui/SceneTransition.gd")
const TRANSITION_FADE_OUT := 0.5
const TRANSITION_FADE_IN := 0.3

var _transition: SceneTransitionScript
var _is_transitioning := false


func _ready() -> void:
  _transition = SceneTransitionScript.new()
  _transition.name = "SceneTransition"
  add_child(_transition)


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
func change_to_title(with_fade: bool = true):
  """タイトルへ遷移する。起動直後（Boot）は暗転させる前の画面が無いので with_fade=false で呼ぶ。"""
  _change_scene(title_scene, with_fade)


func start_stage():
  if _is_transitioning:
    return  # 遷移中の再要求でBGMを止め直さない
  # メニューを抜けるのでBGMをフェードアウト（ステージBGMはステージ側で改めて再生される）
  stop_menu_bgm()
  _change_scene(stage_scene)


func start_equipment_screen():
  _change_scene(equipment_scene)


func start_result_inventory():
  _change_scene(result_inventory_scene)


func start_stage_select_screen():
  _change_scene(stage_select_scene)


func is_transitioning() -> bool:
  return _is_transitioning


#-------------------------------------------------
func _change_scene(path: String, with_fade: bool = true) -> void:
  """フェードアウト → シーン切り替え → フェードイン の順で遷移する。

  遷移中に届いた別の遷移要求は無視する（ボタン連打や重複呼び出し対策）。"""
  if _is_transitioning:
    return

  if not with_fade:
    get_tree().change_scene_to_file(path)
    return

  _is_transitioning = true
  await _transition.fade_out(TRANSITION_FADE_OUT)

  var err := get_tree().change_scene_to_file(path)
  if err != OK:
    push_error("GameFlow: Failed to change scene to %s (error %d)" % [path, err])
  else:
    # 新シーンはフレーム末尾で追加されるので、_ready まで済んでから明ける
    await get_tree().process_frame

  await _transition.fade_in(TRANSITION_FADE_IN)
  _is_transitioning = false

#-------------------------------------------------
