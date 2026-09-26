extends Node
## 2つの AudioStreamPlayer でBGMをクロスフェードする。
##
## 再生/停止リクエストが短時間に重なっても破綻しないよう、以下を守る:
##   1. 新リクエスト時は走行中の tween を必ず kill する（複数tweenが同じ
##      volume_db を奪い合う／取り残された tween が誤ったプレイヤーを止める事故を防ぐ）
##   2. _active の切り替えは await を挟まず同期的に確定する
##   3. 停止は退場するプレイヤーを束縛した tween_callback で行い、_active.stop() は使わない
var _a := AudioStreamPlayer.new()
var _b := AudioStreamPlayer.new()
var _active: AudioStreamPlayer = _a
var _tween: Tween


func _ready():
  # ポーズ中もBGMを継続再生
  process_mode = Node.PROCESS_MODE_ALWAYS

  add_child(_a)
  add_child(_b)
  _a.bus = "Music"
  _b.bus = "Music"

  StageSignals.bgm_play_requested.connect(_on_play_request)
  StageSignals.bgm_stop_requested.connect(_on_stop_request)


func _on_play_request(stream: AudioStream, fade: float, maxdb: float) -> void:
  # 遷移中でなく、既に同じ曲を再生中なら何もしない。
  # （停止中は _active.stream が残っていても必ず鳴らし直す＝再開始時の無音バグ対策）
  if _active.playing and _active.stream == stream and not _is_tween_running():
    return

  _kill_tween()

  var next := _b if _active == _a else _a
  var prev := _active

  next.stream = stream
  next.volume_db = -40
  next.play()

  # await を挟まず同期的に active を確定（遅延コールバックによる取り違えを防ぐ）
  _active = next

  _tween = create_tween()
  _tween.tween_property(next, "volume_db", maxdb, fade)
  _tween.parallel().tween_property(prev, "volume_db", -40, fade)
  # フェード完了後、退場したプレイヤーだけを確実に停止する
  _tween.chain().tween_callback(prev.stop)


func _on_stop_request(fade: float) -> void:
  _kill_tween()

  # クロスフェード中断で取り残された旧プレイヤーを確実に停止
  var other := _b if _active == _a else _a
  other.stop()

  if not _active.playing:
    return

  var target := _active
  _tween = create_tween()
  _tween.tween_property(target, "volume_db", -40, fade)
  _tween.tween_callback(target.stop)


func is_playing_stream(stream: AudioStream) -> bool:
  """指定ストリームが現在アクティブに再生中か（フェード中も含む）。
  呼び出し側が「既に鳴っているなら再リクエストしない」判断をするための問い合わせ用。"""
  return _active.playing and _active.stream == stream


func _kill_tween() -> void:
  if _tween and _tween.is_valid():
    _tween.kill()
  _tween = null


func _is_tween_running() -> bool:
  return _tween != null and _tween.is_valid()
