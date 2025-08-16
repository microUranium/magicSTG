# ExplosionFactory.gd - 爆発エフェクト管理とオブジェクトプール
extends Node
class_name ExplosionFactory

const EXPLOSION_SCENE = preload("res://scenes/effects/explosion_effect.tscn")

# エフェクトプール（パフォーマンス最適化）
static var _explosion_pool: Array[ExplosionEffect] = []
static var _pool_max_size: int = 20


static func create_explosion(config: ExplosionConfig, position: Vector2, source_group: String = ""):
  """爆発エフェクトを生成"""
  if not config:
    return null

  var explosion = _get_pooled_explosion()

  # 先にシーンに追加してからinitialize（重要）
  var scene_root = _get_scene_root()
  if scene_root:
    scene_root.add_child(explosion)
    explosion.initialize(config, position, source_group)

  return explosion


static func _get_pooled_explosion() -> ExplosionEffect:
  """プールから爆発エフェクトを取得または新規作成"""
  if _explosion_pool.size() > 0:
    var explosion = _explosion_pool.pop_back()
    explosion.reset()
    return explosion
  else:
    return EXPLOSION_SCENE.instantiate()


static func return_to_pool(explosion: ExplosionEffect):
  """爆発エフェクトをプールに返却"""
  if not is_instance_valid(explosion):
    return

  if _explosion_pool.size() < _pool_max_size:
    explosion.reset()
    if explosion.get_parent():
      explosion.get_parent().remove_child(explosion)
    _explosion_pool.append(explosion)
  else:
    explosion.queue_free()


static func _get_scene_root() -> Node:
  """現在のシーンルートを取得"""
  var tree = Engine.get_main_loop() as SceneTree
  if tree:
    return tree.current_scene
  return null


static func clear_pool():
  """プールをクリア（シーン切り替え時などに使用）"""
  for explosion in _explosion_pool:
    if is_instance_valid(explosion):
      explosion.queue_free()
  _explosion_pool.clear()
