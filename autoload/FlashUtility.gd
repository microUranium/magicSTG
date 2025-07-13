extends Node

## AnimatedSprite2D を一瞬だけフラッシュ
static func flash_white(node: AnimatedSprite2D, duration := 0.1):
  if node == null:
    return
  node.modulate = Color(1.0, 0.35, 0.35)
  await node.get_tree().create_timer(duration).timeout
  # ノードがまだ生きているか念のためチェック
  if is_instance_valid(node):
    node.modulate = Color(1.0, 1.0, 1.0)