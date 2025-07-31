extends UniversalAttackCore
class_name TestableUniversalAttackCore

var spawned_bullets: Array[Node2D] = []


func _spawn_bullet(pattern: AttackPattern, direction: Vector2, spawn_pos: Vector2) -> bool:
  """テスト用：実際の弾丸生成をスキップ"""
  # モック弾丸を作成
  var mock_bullet = Node2D.new()
  mock_bullet.set_script(BulletStub)

  # 設定を適用
  mock_bullet.global_position = spawn_pos
  mock_bullet.direction = direction
  mock_bullet.speed = pattern.bullet_speed
  mock_bullet.damage = pattern.damage

  # 追跡用に配列に追加
  spawned_bullets.append(mock_bullet)

  return true  # 常に成功


func get_spawned_bullet_count() -> int:
  return spawned_bullets.size()


func clear_spawned_bullets():
  spawned_bullets.clear()


func _create_barrier_bullet(
  pattern: AttackPattern, index: int, group_id: String, target_pos: Vector2
):
  """テスト用：バリア弾もモック弾として追跡"""
  # モック弾丸を作成
  var mock_bullet = Node2D.new()
  mock_bullet.set_script(BulletStub)

  # バリア弾設定を適用
  mock_bullet.damage = pattern.damage
  mock_bullet.target_group = pattern.target_group

  # 追跡用に配列に追加
  spawned_bullets.append(mock_bullet)

  return mock_bullet


func set_owner_actor(new_owner: Node) -> void:
  _owner_actor = new_owner
