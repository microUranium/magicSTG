# パターン化された敵AIのベースクラス
extends EnemyAIBase
class_name EnemyPatternedAIBase

@warning_ignore("unused_signal")
signal phase_changed(phase_idx: int)  # フェーズ遷移をHPバー等へ通知（各ボスAIの _next_phase で emit）

@export var patterns: Array[EnemyPatternResource] = []  # パターンのリスト
@export var loop_type: int = 0  # 0 = SEQ, 1 = RANDOM
@export var skip_dialogue: bool = false  # ダイアログをスキップするかどうか
@export var skip_bgm_change: bool = false  # BGM変更をスキップするかどうか

var _idx: int = 0
var _current: EnemyPatternResource
var _token: int = 0
var _active_tw: Tween = null
var _last_movement_direction: Vector2 = Vector2.ZERO  # 前回の移動方向を記憶
var _stage_lifecycle: StageLifecycleController = null
var _player_control_blocked: bool = false  # 演出パターンによる操作ロック中か
## 実行中のパターンが切り替えたアニメーションの戻し先（戻さない場合は空）。
## パターンの正常終了時と打ち切り時（_cancel_current_pattern）に戻す。
## 戻し先を敵ごとに持つため、パターンのリソース（複数の敵で共有されうる）には記録しない
var _anim_to_restore: String = ""


func _enter_tree() -> void:
  # ステージ選択画面でダイアログを無効にしたステージでは、すべての個体で会話を省略する。
  # 継承先の _ready（最初のパターン選択）より前に確定させるため _enter_tree で判定する
  if StageDataManager.is_dialogue_skipped():
    skip_dialogue = true


func _ready():
  super._ready()
  _stage_lifecycle = (
    get_tree().root.get_node_or_null("Main/LifecycleController") as StageLifecycleController
  )
  if _stage_lifecycle == null:
    print_debug("EnemyPatternedAIBase: StageLifecycleController not found in scene tree")
  _next_pattern()


func _next_pattern():
  if _stage_lifecycle and not _stage_lifecycle.is_stage_running():
    print_debug("EnemyPatternedAIBase: Stage not running, skipping pattern execution")
    return

  _current = (
    patterns[randi() % patterns.size()] if loop_type == 1 else patterns[_idx % patterns.size()]
  )

  if loop_type == 0:
    _idx += 1

  _token += 1

  # 演出パターン中は会話中と同様にプレイヤー操作を止める。
  # 会話を省略する個体（ランダムステージのボス等）では演出も省略扱いとし、操作は止めない
  _set_player_control_blocked(_current.block_player_control and not skip_dialogue)

  if skip_dialogue and (_current.dialogue_path != "" or _current.skip_on_dialogue_skip):
    _on_pattern_finished(_token)  # ダイアログをスキップしてパターン完了を通知
    return

  # アニメーションはパターン側（start）で切り替わるので、その前に戻し先を記録する
  _anim_to_restore = _animation_to_restore_for(_current)
  _active_tw = _current.start(
    enemy_node, self, Callable(self, "_on_pattern_completed").bind(_token)
  )


func _on_pattern_completed(cb_token: int) -> void:
  """パターンからの完了通知。打ち切り済みの古いパターン（待機タイマーは止まらず後から届く）の
  通知ではアニメーションを戻さない（戻すと、次のパターンが再生中のアニメーションを上書きしてしまう）"""
  if cb_token == _token:
    _restore_pattern_animation()
  _on_pattern_finished(cb_token)


func _on_pattern_finished(cb_token: int) -> void:
  print_debug("Pattern finished, token: ", cb_token, " current token: ", _token)
  if cb_token != _token:  # 古いパターンは無視
    return

  if _stage_lifecycle and not _stage_lifecycle.is_stage_running():
    print_debug("EnemyPatternedAIBase: Stage not running, skipping pattern execution")
    return

  _next_pattern()


func _try_skip_dialogue_phase() -> bool:
  """会話を省略する個体で、現在のフェーズ（patterns）が会話を含むなら省略する。
  フェーズ内で最後に移動する先（＝次フェーズの開始位置）へ即時移動し true を返す。
  呼び出し側は true のときパターンを開始せず、そのまま次のフェーズへ進めること。"""
  if not skip_dialogue:
    return false

  var has_dialogue := false
  var destination = null
  for pattern in patterns:
    if pattern.dialogue_path != "":
      has_dialogue = true
    elif pattern.movement_type == EnemyPatternResource.MovementType.MOVE_TO_POSITION:
      destination = pattern.move_to

  if not has_dialogue:
    return false

  if destination != null and is_instance_valid(enemy_node):
    enemy_node.global_position = destination
  return true


func get_last_movement_direction() -> Vector2:
  return _last_movement_direction


func set_last_movement_direction(direction: Vector2) -> void:
  _last_movement_direction = direction.normalized()
  print_debug("EnemyPatternedAIBase: Stored movement direction: ", _last_movement_direction)


func _cancel_current_pattern() -> void:
  if _active_tw and _active_tw.is_valid():
    _active_tw.kill()
  _active_tw = null
  # 打ち切ったパターンが切り替えたアニメーションをすぐ戻す。戻さないと、次のパターンが
  # 「戻し先」として切り替え後のアニメーション（attack など）を記録してしまう
  _restore_pattern_animation()
  _token += 1
  _set_player_control_blocked(false)


func _get_animated_sprite() -> AnimatedSprite2D:
  if not is_instance_valid(enemy_node):
    return null
  return enemy_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _animation_to_restore_for(pattern: EnemyPatternResource) -> String:
  """pattern がアニメーションを切り替えて、終了時に戻す設定なら、今のアニメーション名（戻し先）を返す"""
  if not pattern.change_animation or not pattern.restore_animation:
    return ""
  if pattern.animation_name.is_empty():
    return ""
  var sprite := _get_animated_sprite()
  if sprite == null or sprite.sprite_frames == null:
    return ""
  if not sprite.sprite_frames.has_animation(pattern.animation_name):
    return ""  # 切り替え先がなければパターン側も切り替えない
  return String(sprite.animation)


func _restore_pattern_animation() -> void:
  if _anim_to_restore.is_empty():
    return
  var anim := _anim_to_restore
  _anim_to_restore = ""
  var sprite := _get_animated_sprite()
  if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
    sprite.play(anim)


func _exit_tree() -> void:
  # 演出途中で敵が消えた場合に操作ロックが残らないようにする
  _set_player_control_blocked(false)


func _set_player_control_blocked(blocked: bool) -> void:
  """演出によるプレイヤー操作ロックの ON/OFF"""
  if blocked:
    # 会話終了時に StageController 側で一括解除されるため、毎回ロックを掛け直す
    _player_control_blocked = true
    StageSignals.emit_cutscene_pause_requested(true)
    return

  if not _player_control_blocked:
    return
  _player_control_blocked = false

  # ステージ終了時はステージ側がポーズ状態を管理するため、ここでは解除しない
  if is_instance_valid(_stage_lifecycle) and not _stage_lifecycle.is_stage_running():
    return
  StageSignals.emit_cutscene_pause_requested(false)
