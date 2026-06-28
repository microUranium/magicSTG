extends Node2D
## ボスにオーバーレイ表示する、フェーズ単位でリセットされるHPバー。
##
## - HP は単一プールだが、戦闘フェーズごとの HP 区間 [low, high] を 0〜100% に
##   正規化して表示する。
## - フェーズ開始時は 0 から区間満タンまで約 0.5s かけて対数的に充填する。
## - ボスが rush 等で回転・拡大しても影響を受けないよう top_level で追従する。

const FILL_DURATION := 0.5  # 充填アニメーションの所要時間（秒）

@export var follow_offset: Vector2 = Vector2(0, 70)  # ボス中心からのオフセット（下寄り）

@onready var _bar: TextureProgressBar = $ProgressBar

var _low_hp: int = 0
var _high_hp: int = 1
var _filling: bool = false
var _fill_tween: Tween = null


func _ready() -> void:
  top_level = true  # 親（ボス）の回転・拡大の影響を受けない
  _bar.max_value = 100.0
  _bar.value = 0.0


func _process(_delta: float) -> void:
  var parent := get_parent() as Node2D
  if parent:
    global_position = parent.global_position + follow_offset


## 戦闘フェーズ開始：区間を設定し 0 から現在HP相当まで対数的に充填する。
func begin_phase(low_hp: int, high_hp: int, current_hp: int) -> void:
  _low_hp = low_hp
  _high_hp = high_hp
  visible = true

  var target := _ratio_to_value(current_hp)
  _bar.value = 0.0
  _filling = true

  if _fill_tween and _fill_tween.is_valid():
    _fill_tween.kill()
  _fill_tween = create_tween()
  (
    _fill_tween
    . tween_property(_bar, "value", target, FILL_DURATION)
    . set_trans(Tween.TRANS_EXPO)
    . set_ease(Tween.EASE_OUT)
  )
  _fill_tween.finished.connect(func(): _filling = false)


## 区間内のHP減少を即時反映する（充填アニメ中は無視）。
func update_hp(current_hp: int) -> void:
  if _filling:
    return
  _bar.value = _ratio_to_value(current_hp)


## 会話/導入フェーズ等でバーを隠す。
func hide_bar() -> void:
  visible = false


func _ratio_to_value(current_hp: int) -> float:
  var span := float(_high_hp - _low_hp)
  if span <= 0.0:
    return 0.0
  var ratio: float = clamp((float(current_hp) - _low_hp) / span, 0.0, 1.0)
  return ratio * 100.0
