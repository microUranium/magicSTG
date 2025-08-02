extends Node
class_name StageUIController

signal ready_prompt_finished
signal clear_prompt_finished
signal gameover_prompt_finished

#---------------------------------------------------------------------
# Inspector
#---------------------------------------------------------------------
@export var ready_prompt_scene: PackedScene = preload("res://scenes/ui/ready_prompt.tscn")
@export var clear_prompt_scene: PackedScene = preload("res://scenes/ui/stageclear_prompt.tscn")
@export var gameover_prompt_scene: PackedScene = preload("res://scenes/ui/gameover_prompt.tscn")

#---------------------------------------------------------------------
# Runtime
#---------------------------------------------------------------------
var _parent_node: Node
var _current_prompt: Node


#---------------------------------------------------------------------
# Initialization
#---------------------------------------------------------------------
func initialize(parent: Node) -> bool:
  """UIControllerを初期化"""
  _parent_node = parent
  return true


#---------------------------------------------------------------------
# Public Interface
#---------------------------------------------------------------------


func has_ready_prompt() -> bool:
  """Readyプロンプトが設定されているかチェック"""
  return ready_prompt_scene != null


func show_ready_prompt() -> void:
  """Readyプロンプトを表示"""
  if ready_prompt_scene:
    _show_prompt(ready_prompt_scene, ready_prompt_finished)


func show_clear_prompt() -> void:
  """ステージクリアプロンプトを表示"""
  if clear_prompt_scene:
    _show_prompt(clear_prompt_scene, clear_prompt_finished)


func show_gameover_prompt() -> void:
  """ゲームオーバープロンプトを表示"""
  if gameover_prompt_scene:
    _show_prompt(gameover_prompt_scene, gameover_prompt_finished)


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------


func _show_prompt(scene: PackedScene, finished_signal: Signal) -> void:
  """プロンプトを表示し、完了シグナルに接続"""
  if not _parent_node:
    push_error("StageUIController: Parent node not set. Call initialize() first.")
    return

    # プロンプトの完了シグナルを監視
  var prompt := scene.instantiate()
  _current_prompt = prompt
  _parent_node.add_child(prompt)

  # プロンプトの完了シグナルを監視
  if prompt.has_signal("finished"):
    prompt.finished.connect(func(): _on_prompt_finished(finished_signal))
  else:
    push_warning("StageUIController: Prompt scene does not have 'finished' signal")
    finished_signal.emit()


func _on_prompt_finished(finished_signal: Signal) -> void:
  """プロンプト完了時の処理"""
  _current_prompt = null
  finished_signal.emit()


#---------------------------------------------------------------------
# Stage Event Handlers
#---------------------------------------------------------------------


func handle_stage_cleared() -> void:
  """ステージクリア時のUI処理"""
  show_clear_prompt()


func handle_game_over() -> void:
  """ゲームオーバー時のUI処理"""
  show_gameover_prompt()
