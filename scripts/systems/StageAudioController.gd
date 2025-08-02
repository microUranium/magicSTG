extends Node
class_name StageAudioController

#---------------------------------------------------------------------
# Inspector
#---------------------------------------------------------------------
@export var stage_bgm: AudioStream
@export var stageclear_bgm: AudioStream
@export var bgm_fade_in: float = 2.0
@export var bgm_fade_out: float = 1.0

#---------------------------------------------------------------------
# Public Interface
#---------------------------------------------------------------------


func play_stage_bgm() -> void:
  """ステージ開始時のBGMを再生"""
  if stage_bgm:
    StageSignals.emit_bgm_play_requested(stage_bgm, bgm_fade_in, -10)


func play_stage_clear_bgm() -> void:
  """ステージクリア時のBGMを再生"""
  if stageclear_bgm:
    StageSignals.emit_bgm_play_requested(stageclear_bgm, 0.5, -10)


func stop_bgm() -> void:
  """BGMを停止"""
  StageSignals.emit_bgm_stop_requested(bgm_fade_out)


func play_gameover_sfx() -> void:
  """ゲームオーバー時のSFXを再生"""
  StageSignals.emit_signal("sfx_play_requested", "gameover", Vector2.INF, -10, 0)


#---------------------------------------------------------------------
# Stage Event Handlers
#---------------------------------------------------------------------


func handle_stage_start() -> void:
  """ステージ開始時の音響処理"""
  play_stage_bgm()


func handle_stage_cleared() -> void:
  """ステージクリア時の音響処理"""
  stop_bgm()
  play_stage_clear_bgm()

  # ステージクリア後の音響終了処理
  await get_tree().create_timer(5.0).timeout
  stop_bgm()


func handle_game_over() -> void:
  """ゲームオーバー時の音響処理"""
  stop_bgm()
  play_gameover_sfx()
