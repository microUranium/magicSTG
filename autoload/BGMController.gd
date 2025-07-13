extends Node
## 2 AudioStreamPlayers でクロスフェード
var _a := AudioStreamPlayer.new()
var _b := AudioStreamPlayer.new()
var _active : AudioStreamPlayer = _a

func _ready():
  add_child(_a); add_child(_b)
  _a.bus = "Music"; _b.bus = "Music"

  StageSignals.bgm_play_requested.connect(_on_play_request)
  StageSignals.bgm_stop_requested.connect(_on_stop_request)

func _on_play_request(stream:AudioStream, fade:float, maxdb: float) -> void:
  if _active.stream == stream:
    return
  var next := (_a if _active == _b else _b)
  next.stream = stream
  next.volume_db = -40
  next.play()

  var tw := create_tween()
  tw.parallel().tween_property(next,  "volume_db", maxdb,   fade)
  tw.parallel().tween_property(_active,"volume_db", -40, fade)
  tw.play()
  await tw.finished
  _active.stop()
  _active = next

func _on_stop_request(fade:float) -> void:
  if not _active.playing: return
  var tw := create_tween()
  tw.tween_property(_active, "volume_db", -40, fade)
  await tw.finished
  _active.stop()