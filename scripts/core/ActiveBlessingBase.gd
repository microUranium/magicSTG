extends BlessingBase
class_name ActiveBlessingBase

## キー入力で発動するアクティブ加護の基底クラス。
## ・1ステージあたりの使用回数制限（装備=ステージ開始ごとにリセット）
## ・発動後の短いクールダウン
## 子クラスは _do_activate() に実効果を実装する。

signal activated(uses_remaining: int)
signal activation_failed

@export var max_uses: int = 3  # 1ステージあたりの使用可能回数
@export var cooldown_sec: float = 1.0  # 連続発動を防ぐ短いクールダウン

var _uses_remaining: int = 0
var _on_cooldown: bool = false
var _cooldown_timer: Timer


func _ready() -> void:
  super._ready()

  _cooldown_timer = Timer.new()
  _cooldown_timer.name = "CooldownTimer"
  _cooldown_timer.one_shot = true
  add_child(_cooldown_timer)
  _cooldown_timer.timeout.connect(_on_cooldown_finished)
  register_timer(_cooldown_timer)  # ポーズ管理対象（ポーズ中はクールダウンも停止）


func _recalc_stats() -> void:
  max_uses = int(_proto.base_modifiers.get("max_uses", max_uses) + _sum_add("blessing_uses_add"))
  cooldown_sec = _proto.base_modifiers.get("blessing_cooldown_sec", cooldown_sec)


func on_equip(_player) -> void:
  _recalc_stats()
  _uses_remaining = max_uses  # ステージ開始時に回数リセット
  _on_cooldown = false
  # 残使用回数をHUDゲージに表示（durability スタイルを流用）
  init_gauge("durability", float(max_uses), float(_uses_remaining), _proto.display_name)


func can_activate() -> bool:
  return not _paused and not _on_cooldown and _uses_remaining > 0


## スロットキー押下時に BlessingContainer から呼ばれる
func activate() -> bool:
  if not can_activate():
    emit_signal("activation_failed")
    return false

  if not _do_activate():  # 子クラスの実効果。失敗時は回数を消費しない
    emit_signal("activation_failed")
    return false

  _uses_remaining -= 1
  set_gauge(float(_uses_remaining))
  _on_cooldown = true
  _cooldown_timer.start(cooldown_sec)
  emit_signal("activated", _uses_remaining)
  return true


func _do_activate() -> bool:
  """子クラスでオーバーライド。成功したら true を返す。"""
  push_warning("ActiveBlessingBase: _do_activate() not implemented")
  return false


func _on_cooldown_finished() -> void:
  _on_cooldown = false


func get_uses_remaining() -> int:
  return _uses_remaining
