extends Node

@export var catalog: SFXCatalog = preload("res://assets/SFX/SFX_Catalog.tres")
@export var pool_size_2d := 16
@export var pool_size_ui := 8

## 同一SFXの同フレーム重複再生を1音に間引く（音量スパイクとプール枯渇の抑制）
@export var coalesce_enabled: bool = true
## コアレッシング対象外の名前（同フレームでも複数鳴らしたい音をここへ）
@export var coalesce_exceptions: Array[String] = []

var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_ui: Array[AudioStreamPlayer] = []

# ボイススチール用: プールと同じ添字で「鳴らし始めた順序」を保持（若い=古い音）
var _seq_2d: Array[int] = []
var _seq_ui: Array[int] = []
var _play_seq: int = 0

# コアレッシング用: コアレッシングキー(SFX名 or リソースパス) -> 最後に再生した物理フレーム
var _last_play_frame: Dictionary = {}


func _ready():
  StageSignals.sfx_play_requested.connect(_on_request)
  StageSignals.sfx_play_stream_requested.connect(_on_stream_request)
  _init_pools()


func _init_pools():
  for i in pool_size_2d:
    var p := AudioStreamPlayer2D.new()
    p.bus = "SFX"
    add_child(p)
    _pool_2d.append(p)
    _seq_2d.append(0)
  for i in pool_size_ui:
    var p := AudioStreamPlayer.new()
    p.bus = "SFX_UI"
    add_child(p)
    _pool_ui.append(p)
    _seq_ui.append(0)


func _on_request(sfx_name: String, pos: Vector2, vol: float, pitch: float):
  """カタログ名でのSFX再生リクエスト"""
  var stream: AudioStream = catalog.table.get(sfx_name)
  if stream == null:
    print("SFX not found in catalog: ", sfx_name)
    return

  _play(stream, sfx_name, pos, vol, pitch)


func _on_stream_request(stream: AudioStream, pos: Vector2, vol: float, pitch: float):
  """AudioStream直接指定でのSFX再生リクエスト（弾発射音などカタログ外の音）"""
  if stream == null:
    return

  # コアレッシングキーはリソースパス（preload共有されるため同一音を横断的に畳める）。
  # パスを持たない動的生成ストリームはインスタンスIDで代用。
  var key := (
    stream.resource_path if not stream.resource_path.is_empty() else str(stream.get_instance_id())
  )
  _play(stream, key, pos, vol, pitch)


func _play(stream: AudioStream, coalesce_key: String, pos: Vector2, vol: float, pitch: float):
  # ① コアレッシング: 同フレームに同じ音が既に鳴っていれば捨てる
  if coalesce_enabled and coalesce_key not in coalesce_exceptions:
    var frame := Engine.get_physics_frames()
    if _last_play_frame.get(coalesce_key) == frame:
      return
    _last_play_frame[coalesce_key] = frame

  # ② ボイス確保: 空きが無ければ最古を奪う（サイレントドロップしない）
  var use_ui := pos == Vector2.INF
  var pool: Array
  var seqs: Array
  if use_ui:
    pool = _pool_ui
    seqs = _seq_ui
  else:
    pool = _pool_2d
    seqs = _seq_2d

  var idx := _acquire(pool, seqs)
  var player = pool[idx]

  player.stream = stream
  player.volume_db = vol
  player.pitch_scale = pitch
  if not use_ui:
    player.global_position = pos
  player.play()

  seqs[idx] = _play_seq
  _play_seq += 1


func _acquire(pool: Array, seqs: Array) -> int:
  # 1) 空きプレイヤーを探す
  for i in pool.size():
    if not pool[i].playing:
      return i

  # 2) 全て再生中なら最も古く鳴り始めたプレイヤーを奪う
  var oldest := 0
  for i in range(1, pool.size()):
    if seqs[i] < seqs[oldest]:
      oldest = i
  pool[oldest].stop()
  return oldest
