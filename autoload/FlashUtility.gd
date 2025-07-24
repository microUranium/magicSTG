extends Node


## AnimatedSprite2D を一瞬だけフラッシュ
static func flash_white(node: AnimatedSprite2D, duration := 0.1):
  if node == null:
    return

  # 現在時刻（ミリ秒）を記録
  var now := Time.get_ticks_msec()
  node.set_meta("_last_flash_ms", now)

  # 色を即座に赤へ
  node.modulate = Color(1.0, 0.35, 0.35)

  # duration 後に戻すか判定
  await node.get_tree().create_timer(duration).timeout

  if !is_instance_valid(node):
    return

  # 直近のヒットから duration 経っていなければ戻さない
  var last: int = node.get_meta("_last_flash_ms", 0)
  if Time.get_ticks_msec() - last >= duration * 1000.0 - 1.0:
    node.modulate = Color(1.0, 1.0, 1.0)
