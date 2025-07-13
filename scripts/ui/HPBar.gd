extends TextureProgressBar


func update_hp(current_hp: int, max_hp: int):
  max_value = 100  # 表示は常に0～100%ベースにする

  var hp_ratio = clamp(float(current_hp) / float(max_hp), 0.0, 1.0)
  var display_ratio = 0.05 + hp_ratio * 0.90

  value = display_ratio * 100
