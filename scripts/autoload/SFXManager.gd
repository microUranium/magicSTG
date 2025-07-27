extends Node

@export var catalog: SFXCatalog = preload("res://assets/SFX/SFX_Catalog.tres")
@export var pool_size_2d := 16
@export var pool_size_ui := 8

var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_ui: Array[AudioStreamPlayer] = []


func _ready():
  StageSignals.sfx_play_requested.connect(_on_request)
  _init_pools()


func _init_pools():
  for i in pool_size_2d:
    var p := AudioStreamPlayer2D.new()
    p.bus = "SFX"
    add_child(p)
    _pool_2d.append(p)
  for i in pool_size_ui:
    var p := AudioStreamPlayer.new()
    p.bus = "SFX_UI"
    add_child(p)
    _pool_ui.append(p)


func _on_request(name: String, pos: Vector2, vol: float, pitch: float):
  var stream: AudioStream = catalog.table.get(name)
  if stream == null:
    print("SFX not found in catalog: ", name)
    return

  var player = _get_free_ui() if pos == Vector2.INF else _get_free_2d()
  if player == null:
    return  # プール枯渇時は無視 or 拡張

  player.stream = stream
  player.volume_db = vol
  player.pitch_scale = pitch
  if pos != Vector2.INF:
    player.global_position = pos
  player.play()


func _get_free_2d():
  for p in _pool_2d:
    if not p.playing:
      return p
  return null


func _get_free_ui():
  for p in _pool_ui:
    if not p.playing:
      return p
  return null
