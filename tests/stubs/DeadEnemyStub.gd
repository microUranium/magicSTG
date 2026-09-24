# 撃破処理中（_is_dead = true）だが、まだ "enemies" グループに残っている敵のスタブ。
# 追尾のロック対象から除外されることを確認するために使う。
extends Area2D

# UniversalBullet._find_homing_lock_target() が外部から参照する
@warning_ignore("unused_private_class_variable")
var _is_dead: bool = true
