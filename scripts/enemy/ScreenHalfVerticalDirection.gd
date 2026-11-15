extends RefCounted

## AttackPattern.custom_script（DirectionType.CUSTOM）用の方向計算。
## 発射元がプレイエリアの上半分にいれば下向き、下半分にいれば上向きを返す。
## 警告線を出す時点で一度だけ呼ばれ、警告線とビームはその向きのまま発射元に追従する。


static func calculate_direction(
  from_pos: Vector2, _target_pos: Vector2, _params: Dictionary
) -> Vector2:
  var center_y := PlayArea.get_play_rect().get_center().y
  return Vector2.DOWN if from_pos.y < center_y else Vector2.UP
