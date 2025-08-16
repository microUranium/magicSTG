# === WormSegmentManager ワーム節管理システムテスト ===
extends GdUnitTestSuite
class_name WormSegmentManagerTest

var manager: WormSegmentManager
var test_scene: Node2D
var mock_head: Node2D
var mock_segment_scene: PackedScene


func before_test():
  # テストシーン構築
  test_scene = Node2D.new()
  test_scene.name = "TestScene"
  add_child(test_scene)

  # モックヘッドノード（ワームボス頭部）
  mock_head = Node2D.new()
  mock_head.name = "MockWormHead"
  mock_head.position = Vector2(100, 100)
  test_scene.add_child(mock_head)

  # WormSegmentManagerインスタンス作成
  manager = WormSegmentManager.new()
  manager.name = "WormSegmentManager"
  test_scene.add_child(manager)

  # モックセグメントシーンの準備
  mock_segment_scene = _create_mock_segment_scene()


func after_test():
  if test_scene:
    test_scene.queue_free()


func _create_mock_segment_scene() -> PackedScene:
  """モックセグメントシーンの作成"""
  var mock_segment = Area2D.new()
  mock_segment.name = "MockWormSegment"
  mock_segment.set_script(load("res://scripts/enemy/WormSegment.gd"))

  # WormSegmentに必要なコンポーネントを追加
  var collision_shape = CollisionShape2D.new()
  collision_shape.name = "CollisionShape2D"
  collision_shape.shape = RectangleShape2D.new()
  mock_segment.add_child(collision_shape)

  var animated_sprite = AnimatedSprite2D.new()
  animated_sprite.name = "AnimatedSprite2D"
  mock_segment.add_child(animated_sprite)

  var packed_scene = PackedScene.new()
  packed_scene.pack(mock_segment)
  return packed_scene


# === 基本初期化テスト ===


func test_manager_default_configuration():
  """マネージャーデフォルト設定テスト"""
  # デフォルト値確認
  assert_that(manager.segment_count).is_equal(8)
  assert_that(manager.segment_spacing).is_equal(18.0)
  assert_that(manager.base_delay_frames).is_equal(4)
  assert_that(manager.delay_increment).is_equal(1)
  assert_that(manager.debug_draw_connections).is_false()
  assert_that(manager.is_initialized).is_false()


func test_manager_custom_configuration():
  """マネージャーカスタム設定テスト"""
  manager.segment_count = 12
  manager.segment_spacing = 25.0
  manager.base_delay_frames = 6
  manager.delay_increment = 2
  manager.debug_draw_connections = true

  assert_that(manager.segment_count).is_equal(12)
  assert_that(manager.segment_spacing).is_equal(25.0)
  assert_that(manager.base_delay_frames).is_equal(6)
  assert_that(manager.delay_increment).is_equal(2)
  assert_that(manager.debug_draw_connections).is_true()


func test_manager_setup_with_head():
  """ヘッド付きマネージャー設定テスト"""
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  assert_that(manager.head_node).is_equal(mock_head)
  assert_that(manager.is_initialized).is_true()


func test_manager_setup_without_head():
  """ヘッド無しマネージャー設定テスト"""
  manager.setup(null)

  # ヘッドが無い場合は初期化失敗
  assert_that(manager.head_node).is_null()
  assert_that(manager.is_initialized).is_false()


# === セグメント生成・管理テスト ===


func test_segment_creation():
  """セグメント生成テスト"""
  manager.segment_count = 5
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # セグメントが生成されることを確認
  assert_that(manager.segments.size()).is_equal(5)

  # 各セグメントが有効でArea2Dベースであることを確認
  for segment in manager.segments:
    assert_that(segment).is_not_null()
    assert_that(is_instance_valid(segment)).is_true()
    assert_that(segment is Area2D).is_true()

    # WormSegmentの基本プロパティ確認
    assert_that(segment.has_method("setup")).is_true()
    assert_that(segment.follow_delay_frames).is_greater_equal(0)
    assert_that(segment.segment_spacing).is_greater(0.0)


func test_segment_spacing_configuration():
  """セグメント間隔設定テスト"""
  manager.segment_spacing = 30.0
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # 間隔設定が正しく保存されることを確認
  assert_that(manager.segment_spacing).is_equal(30.0)


func test_segment_delay_configuration():
  """セグメント遅延設定テスト"""
  manager.base_delay_frames = 8
  manager.delay_increment = 3
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # 遅延設定が正しく保存されることを確認
  assert_that(manager.base_delay_frames).is_equal(8)
  assert_that(manager.delay_increment).is_equal(3)


func test_zero_segment_count():
  """ゼロセグメント数テスト"""
  manager.segment_count = 0
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # セグメントが生成されないことを確認
  assert_that(manager.segments.size()).is_equal(0)


func test_large_segment_count():
  """大量セグメント数テスト"""
  manager.segment_count = 20  # 50から20に削減（テスト実行速度向上）
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # 大量セグメントでも正常に生成されることを確認
  assert_that(manager.segments.size()).is_equal(20)

  # 各セグメントがArea2Dベースであることを確認
  for segment in manager.segments:
    assert_that(segment is Area2D).is_true()


# === TrailFollowSystem統合テスト ===


func test_head_trail_system_setup():
  """ヘッドTrailFollowSystem設定テスト"""
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # ヘッドにTrailFollowSystemが追加されることを確認
  var trail_system = mock_head.get_node_or_null("TrailFollowSystem")
  assert_that(trail_system).is_not_null()
  assert_that(trail_system is TrailFollowSystem).is_true()


func test_trail_system_configuration():
  """トレイルシステム設定テスト"""
  manager.setup(mock_head)

  # トレイルシステムが適切に設定されることを確認
  var trail_system = mock_head.get_node_or_null("TrailFollowSystem")
  if trail_system and trail_system.has_method("get_history_size"):
    # 設定が適用されていることを確認（実装依存）
    assert_that(trail_system).is_not_null()


# === エラーハンドリング・堅牢性テスト ===


func test_invalid_segment_count():
  """無効セグメント数テスト"""
  # 負の値
  manager.segment_count = -5
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # 負の値でも安全に処理されることを確認
  assert_that(manager.segments.size()).is_equal(0)


func test_invalid_spacing_values():
  """無効間隔値テスト"""
  manager.segment_spacing = -10.0
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # 負の間隔でもエラーにならないことを確認
  assert_that(manager.segment_spacing).is_equal(-10.0)


func test_invalid_delay_values():
  """無効遅延値テスト"""
  manager.base_delay_frames = -3
  manager.delay_increment = -1
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # 負の遅延でもエラーにならないことを確認
  assert_that(manager.base_delay_frames).is_equal(-3)
  assert_that(manager.delay_increment).is_equal(-1)


func test_multiple_setup_calls():
  """複数回設定呼び出しテスト"""
  manager.segment_scene = mock_segment_scene

  # 初回設定
  manager.setup(mock_head)
  var initial_segment_count = manager.segments.size()

  # 再設定
  manager.setup(mock_head)
  var final_segment_count = manager.segments.size()

  # 適切に処理されることを確認
  assert_that(manager.is_initialized).is_true()


# === パフォーマンス・メモリテスト ===


func test_segment_cleanup():
  """セグメントクリーンアップテスト"""
  manager.segment_count = 10
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  var initial_count = manager.segments.size()
  assert_that(initial_count).is_equal(10)

  # セグメントを適切にクリーンアップ
  for segment in manager.segments:
    if is_instance_valid(segment):
      segment.queue_free()

  # セグメントリストをクリア
  manager.segments.clear()
  assert_that(manager.segments.size()).is_equal(0)


func test_memory_usage_large_segments():
  """大量セグメントメモリ使用テスト"""
  manager.segment_count = 50  # 100から50に削減（テスト実行速度向上）
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # 大量セグメントでもメモリエラーが発生しないことを確認
  assert_that(manager.segments.size()).is_equal(50)
  assert_that(manager.is_initialized).is_true()

  # 全セグメントがArea2Dベースで適切に設定されていることを確認
  for i in range(min(5, manager.segments.size())):  # 最初の5個だけチェック（パフォーマンス向上）
    var segment = manager.segments[i]
    assert_that(segment is Area2D).is_true()
    assert_that(segment.is_in_group("enemies")).is_true()


# === デバッグ機能テスト ===


func test_debug_draw_connections_flag():
  """デバッグ描画接続フラグテスト"""
  manager.debug_draw_connections = true
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # フラグが正しく設定されることを確認
  assert_that(manager.debug_draw_connections).is_true()


func test_debug_output():
  """デバッグ出力テスト"""
  manager.segment_scene = mock_segment_scene
  manager.setup(mock_head)

  # デバッグ出力でエラーが発生しないことを確認
  # (print_debugは副作用のみなので、例外が投げられないことを確認)
  assert_that(manager.is_initialized).is_true()


# === 統合・実用性テスト ===


func test_complete_worm_setup():
  """完全ワーム設定テスト"""
  # 実用的な設定
  manager.segment_count = 8
  manager.segment_spacing = 20.0
  manager.base_delay_frames = 5
  manager.delay_increment = 1
  manager.segment_scene = mock_segment_scene

  # 設定実行
  manager.setup(mock_head)

  # 全体設定が正常であることを確認
  assert_that(manager.is_initialized).is_true()
  assert_that(manager.head_node).is_equal(mock_head)
  assert_that(manager.segments.size()).is_equal(8)


func test_worm_manager_independence():
  """ワームマネージャー独立性テスト"""
  var manager2 = WormSegmentManager.new()
  var mock_head2 = Node2D.new()
  test_scene.add_child(manager2)
  test_scene.add_child(mock_head2)

  # 異なる設定
  manager.segment_count = 3
  manager2.segment_count = 5

  manager.segment_scene = mock_segment_scene
  manager2.segment_scene = mock_segment_scene

  manager.setup(mock_head)
  manager2.setup(mock_head2)

  # 独立性確認
  assert_that(manager.segments.size()).is_equal(3)
  assert_that(manager2.segments.size()).is_equal(5)
  assert_that(manager.head_node).is_not_equal(manager2.head_node)

  # 両方のヘッドに独立したTrailFollowSystemが追加される
  var trail1 = mock_head.get_node_or_null("TrailFollowSystem")
  var trail2 = mock_head2.get_node_or_null("TrailFollowSystem")
  assert_that(trail1).is_not_null()
  assert_that(trail2).is_not_null()
  assert_that(trail1).is_not_equal(trail2)


func test_edge_case_configurations():
  """エッジケース設定テスト"""
  # 極端な設定値の組み合わせ
  manager.segment_count = 1
  manager.segment_spacing = 1.0
  manager.base_delay_frames = 0
  manager.delay_increment = 0
  manager.segment_scene = mock_segment_scene

  manager.setup(mock_head)

  # 極端な設定でも動作することを確認
  assert_that(manager.is_initialized).is_true()
  assert_that(manager.segments.size()).is_equal(1)
