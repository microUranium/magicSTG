extends Control

var _icon: TextureRect
var _icon_background: TextureRect
var _bar: TextureProgressBar
var _label: RichTextLabel

var _provider: GaugeProvider  # 後で使う場合に保持


#-------------------------------------------------
# init_from_provider
# GaugeManager から呼ばれ、Provider の初期状態を
# HUD パーツへ反映するエントリポイント
#-------------------------------------------------
func init_from_provider(p: GaugeProvider) -> void:
  _provider = p

  _icon = $Icon
  _icon_background = $IconBackGround
  _bar = $Bar
  _label = $Name

  # 1) アイコン
  if p.gauge_icon:
    _icon.texture = p.gauge_icon
  else:
    _icon.visible = false
    _icon_background.visible = false

  # 2) ラベル
  _label.text = str(p.gauge_label) if p.gauge_label != "" else str(p.name)

  # 3) プログレスバー初期化
  _bar.min_value = 0
  _bar.max_value = p.gauge_max
  _bar.value = p.gauge_current

  # 4) スタイル反映（色 / 方向など）
  update_style(p.gauge_style)

  # ※ Provider からの signal 接続は GaugeManager が担当するため
  #    ここでは行わない（疎結合の維持）


#-------------------------------------------------
# Provider→HUD 値更新を受けるための公開メソッド
# （GaugeManager が provider.connect(..., self, "update_value") で呼ぶ）
#-------------------------------------------------
func update_value(current: float, max_value: float) -> void:
  _bar.max_value = max_value
  _bar.value = clamp(current, 0.0, max_value)


func update_style(style: String) -> void:
  match style:
    "cooldown":
      _bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
      _bar.add_theme_color_override("fg_color", Color.CYAN)
    "durability":
      _bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
      _bar.add_theme_color_override("fg_color", Color.GREEN)
    _:
      _bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
      _bar.add_theme_color_override("fg_color", Color.WHITE)
