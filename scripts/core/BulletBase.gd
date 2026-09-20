extends Area2D
class_name BulletBase

@export var target_group: String = "enemies"
@export var damage: int = 1
var penetration_count: int = 0  # 貫通回数 0=貫通なし 1以上=貫通回数 -1=無限貫通
var hit_count: int = 0  # 現在のヒット回数

# === 1F無敵設定 ===
## 生成後1フレームの衝突を無視するか（拡散弾など、生成位置が敵と重なる場合に使用）
var ignore_first_frame_collision: bool = false
var _spawn_frame: int = 0

# === SHOT_ON_HIT 設定 ===
## ヒット時に実行するパターン
var on_hit_pattern: AttackPattern = null
## ヒット位置から発射するか
var on_hit_use_hit_position: bool = true
## 弾1つにつき1回のみ発動
var on_hit_trigger_once: bool = true
## 発動済みフラグ
var _on_hit_triggered: bool = false

# === 接触継続ダメージ設定 ===
## 接触中のダメージ間隔（秒）。0 = 無効＝従来どおり進入時に1回だけダメージ。
## 有効化は enable_contact_damage() から行う（area_exited の接続もそこで行う）。
var contact_damage_tick_sec: float = 0.0
## 現在コリジョン中のターゲット
var _contact_targets: Array[Node] = []
## tick の経過時間の累積
var _contact_tick_accum: float = 0.0
## 1フレームで処理する tick の上限。
## 長いフレーム落ちの後に累積が一気に消化されて大ダメージが入るのを防ぐ。
const MAX_CONTACT_TICKS_PER_FRAME := 4

# === シグナル ===
## ヒット時パターン発動要求
signal hit_pattern_requested(
  hit_position: Vector2, bullet_position: Vector2, pattern: AttackPattern
)


func _ready():
  _spawn_frame = Engine.get_process_frames()
  connect("area_entered", Callable(self, "_on_area_entered"))
  StageSignals.destroy_bullet.connect(_destroy_bullet)
  StageSignals.destroy_bullets_by_target.connect(_on_destroy_by_target)


func _destroy_bullet() -> void:
  """シグナルによる弾の破壊（即座削除）"""
  _immediate_removal()


func _on_destroy_by_target(group: String) -> void:
  """指定ターゲットグループを狙う弾のみ破壊（打消の加護など）"""
  if target_group == group:
    _immediate_removal()


func _immediate_removal():
  """即座削除（画面外・敵ヒット時）
  ProjectileBullet/UniversalBulletでオーバーライド可能"""
  _create_explosion_effect()
  _handle_particle_cleanup()
  queue_free()


func _handle_particle_cleanup():
  """パーティクルの適切なクリーンアップ処理"""
  # UniversalBulletでオーバーライド予定
  pass


func _create_explosion_effect():
  """爆発エフェクトの生成"""
  # UniversalBulletでオーバーライド予定
  pass


func _resolve_damage(_target: Node) -> int:
  """ヒット時の最終ダメージを算出。
  自弾(target_group=='enemies')はプレイヤーの加護で与ダメージ補正を受ける。"""
  if target_group != "enemies":
    return damage
  var player = TargetService.get_player()
  if is_instance_valid(player) and "blessing_container" in player and player.blessing_container:
    return player.blessing_container.process_outgoing_damage(_target, damage)
  return damage


func enable_contact_damage(tick_sec: float) -> void:
  """接触継続ダメージを有効化する。

  area_exited の接続もここで行うため、_ready の前後どちらから呼んでもよい。
  接続を tick モードの弾だけに限定することで、通常弾にシグナル接続を
  1本増やさずに済む（大量発射時のコスト対策）。
  """
  contact_damage_tick_sec = tick_sec
  if tick_sec > 0.0 and not area_exited.is_connected(_on_area_exited):
    area_exited.connect(_on_area_exited)


func _on_area_entered(body):
  # フラグが有効な場合のみ、生成後1フレームは衝突判定をスキップ（拡散弾の即ヒット防止）
  if ignore_first_frame_collision and Engine.get_process_frames() - _spawn_frame <= 1:
    return

  if body.is_in_group(target_group):
    # 接触継続ダメージモードでは進入時のダメージと貫通判定を行わない。
    # ダメージは _update_contact_damage() が一定間隔で与え、弾は貫通回数では
    # 消滅しない（画面外・寿命・射程でのみ消える）。
    # このため penetration_count は参照されず、貫通エンチャントの影響も受けない。
    if contact_damage_tick_sec > 0.0:
      if body not in _contact_targets:
        _contact_targets.append(body)
      _trigger_on_hit_pattern(body)  # 初回接触イベントは従来どおり発火させる
      return

    body.take_damage(_resolve_damage(body))  # 敵側に take_damage 実装がある前提
    hit_count += 1

    _trigger_on_hit_pattern(body)

    # 貫通判定
    if penetration_count == 0 or (penetration_count > 0 and hit_count > penetration_count):
      # 敵ヒット時は即座削除（フェードアウトなし）
      _immediate_removal()


func _trigger_on_hit_pattern(body) -> void:
  """SHOT_ON_HIT パターンの発動（初回接触イベント）"""
  if on_hit_pattern and (not on_hit_trigger_once or not _on_hit_triggered):
    var hit_pos = (
      body.global_position if body.has_method("get_global_position") else global_position
    )
    hit_pattern_requested.emit(hit_pos, global_position, on_hit_pattern)
    _on_hit_triggered = true


func _on_area_exited(area: Area2D) -> void:
  """コリジョン終了（接触継続ダメージモードのみ接続される）"""
  _contact_targets.erase(area)


func _update_contact_damage(delta: float) -> void:
  """接触中のターゲットへ contact_damage_tick_sec 間隔でダメージを与える。

  フレーム数ではなく経過時間で数える。project.godot に max_fps / vsync の
  指定がないため _process はモニタのリフレッシュレートで回り、
  フレームカウンタだと高リフレッシュレート環境で火力が変わってしまう。

  ProjectileBullet._process() から呼ぶこと。BulletBase に _process() を
  新設しても ProjectileBullet 側が super を呼んでいないため実行されない。
  """
  if contact_damage_tick_sec <= 0.0:
    return

  # 撃破済みなど無効になったターゲットを除去
  _contact_targets = _contact_targets.filter(func(t): return is_instance_valid(t))
  if _contact_targets.is_empty():
    _contact_tick_accum = 0.0
    return

  _contact_tick_accum += delta
  var ticks := 0
  while _contact_tick_accum >= contact_damage_tick_sec and ticks < MAX_CONTACT_TICKS_PER_FRAME:
    _contact_tick_accum -= contact_damage_tick_sec
    ticks += 1
    for target in _contact_targets:
      if is_instance_valid(target) and target.has_method("take_damage"):
        target.take_damage(_resolve_damage(target))

  # 上限に達した場合は積み残しを捨てる（ハング明けの一括発火を防ぐ）
  if ticks >= MAX_CONTACT_TICKS_PER_FRAME:
    _contact_tick_accum = 0.0
