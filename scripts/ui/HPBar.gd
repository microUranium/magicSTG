extends TextureProgressBar

## 追加の体力（庇護）を表示する子バー。通常のバーの上に重ね、減ると後ろの通常バーが見える。
## 画像は ExtraBar ノードの texture_progress（HPBar_progress_extra.png）で差し替えられる。
@onready var _extra_bar: TextureProgressBar = get_node_or_null("ExtraBar")


func update_hp(current_hp: int, max_hp: int):
  max_value = 100  # 表示は常に0～100%ベースにする

  var hp_ratio = clamp(float(current_hp) / float(max_hp), 0.0, 1.0)
  value = _to_display_value(hp_ratio)


## 追加の体力の表示を更新する。長さは「残り ÷ 付与時の量」で、0 になったら非表示。
func update_extra(extra_hp: int, extra_hp_max: int) -> void:
  if _extra_bar == null:
    return
  if extra_hp <= 0 or extra_hp_max <= 0:
    _extra_bar.visible = false
    return
  _extra_bar.visible = true
  _extra_bar.max_value = 100
  _extra_bar.value = _to_display_value(clampf(float(extra_hp) / float(extra_hp_max), 0.0, 1.0))


## 画像の端の飾り部分を避けるため、表示上は 5%〜95% の範囲に収める
func _to_display_value(fill_ratio: float) -> float:
  return (0.05 + fill_ratio * 0.90) * 100
