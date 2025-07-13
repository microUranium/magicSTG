extends GaugeProvider
class_name BlessingBase

signal blessing_updated

func on_equip(_player):
  # プレイヤー装備時に呼ばれる
  pass

func on_unequip(_player):
  # プレイヤーから外れた時に呼ばれる
  pass

func process_damage(_player, damage):
  # 被弾処理に介入したい場合にオーバーライド
  return damage  # デフォルトはダメージそのまま通す