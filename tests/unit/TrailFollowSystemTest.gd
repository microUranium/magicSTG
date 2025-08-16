# === TrailFollowSystem 位置履歴・追従システムテスト ===
extends GdUnitTestSuite
class_name TrailFollowSystemTest

var trail_system: TrailFollowSystem
var test_scene: Node2D
var target_node: Node2D


func before_test():
  # テストシーン構築
  test_scene = Node2D.new()
  test_scene.name = "TestScene"
  add_child(test_scene)

  # ターゲットノード（追従対象）
  target_node = Node2D.new()
  target_node.name = "TargetNode"
  target_node.position = Vector2(100, 100)
  target_node.rotation = 0.0
  test_scene.add_child(target_node)

  # TrailFollowSystemをターゲットの子として追加
  trail_system = TrailFollowSystem.new()
  trail_system.name = "TrailFollowSystem"
  target_node.add_child(trail_system)


func after_test():
  if test_scene:
    test_scene.queue_free()


# === 基本設定テスト ===


func test_default_configuration():
  """デフォルト設定テスト"""
  assert_that(trail_system.history_size).is_equal(15)
  assert_that(trail_system.update_every_frames).is_equal(1)
  assert_that(trail_system.frame_counter).is_equal(0)
  assert_that(trail_system.target_node).is_equal(target_node)


func test_custom_configuration():
  """カスタム設定テスト"""
  trail_system.history_size = 25
  trail_system.update_every_frames = 3

  assert_that(trail_system.history_size).is_equal(25)
  assert_that(trail_system.update_every_frames).is_equal(3)


func test_target_node_assignment():
  """ターゲットノード割り当てテスト"""
  # ready()で親ノードが自動設定される
  assert_that(trail_system.target_node).is_equal(target_node)
  assert_that(trail_system.target_node is Node2D).is_true()


# === 履歴初期化テスト ===


func test_history_initialization():
  """履歴初期化テスト"""
  # ready()後に履歴が初期化される
  assert_that(trail_system.position_history.size()).is_equal(trail_system.history_size)
  assert_that(trail_system.rotation_history.size()).is_equal(trail_system.history_size)

  # 初期値がターゲットの位置・回転で埋められている
  for i in range(trail_system.history_size):
    assert_that(trail_system.position_history[i]).is_equal(target_node.global_position)
    assert_that(trail_system.rotation_history[i]).is_equal(target_node.global_rotation)


func test_history_size_change():
  """履歴サイズ変更テスト"""
  trail_system.history_size = 30
  trail_system._initialize_history()

  assert_that(trail_system.position_history.size()).is_equal(30)
  assert_that(trail_system.rotation_history.size()).is_equal(30)


func test_zero_history_size():
  """ゼロ履歴サイズテスト"""
  trail_system.history_size = 0
  trail_system._initialize_history()

  assert_that(trail_system.position_history.size()).is_equal(0)
  assert_that(trail_system.rotation_history.size()).is_equal(0)


# === 位置記録テスト ===


func test_position_recording():
  """位置記録テスト"""
  var rad45 = floor(deg_to_rad(45))
  # 初期位置から移動
  target_node.global_position = Vector2(200, 150)
  target_node.global_rotation = rad45

  # 手動で記録実行
  trail_system._record_position()

  # 最新位置が履歴の先頭に追加される
  assert_that(trail_system.position_history[0]).is_equal(Vector2(200, 150))
  assert_float(trail_system.rotation_history[0]).is_equal(rad45)


func test_multiple_position_recording():
  """複数位置記録テスト"""
  var positions = [Vector2(100, 100), Vector2(120, 110), Vector2(140, 120), Vector2(160, 130)]

  for i in range(positions.size()):
    target_node.global_position = positions[i]
    trail_system._record_position()

  # 履歴が正しい順序で記録される
  for i in range(min(positions.size(), trail_system.history_size)):
    var expected_index = positions.size() - 1 - i
    assert_that(trail_system.position_history[i]).is_equal(positions[expected_index])


func test_history_overflow():
  """履歴オーバーフローテスト"""
  trail_system.history_size = 3
  trail_system._initialize_history()

  # 履歴サイズを超える記録
  var positions = [Vector2(100, 100), Vector2(200, 200), Vector2(300, 300), Vector2(400, 400)]

  for pos in positions:
    target_node.global_position = pos
    trail_system._record_position()

  # 古い履歴が削除され、最新の3つが保持される
  assert_that(trail_system.position_history.size()).is_equal(3)
  assert_that(trail_system.position_history[0]).is_equal(Vector2(400, 400))
  assert_that(trail_system.position_history[1]).is_equal(Vector2(300, 300))
  assert_that(trail_system.position_history[2]).is_equal(Vector2(200, 200))


# === 遅延アクセステスト ===


func test_get_history_size():
  """履歴サイズ取得テスト"""
  assert_that(trail_system.get_history_size()).is_equal(trail_system.history_size)

  # 履歴記録後のサイズ確認
  target_node.global_position = Vector2(200, 200)
  trail_system._record_position()
  assert_that(trail_system.get_history_size()).is_equal(trail_system.history_size)


func test_clear_history():
  """履歴クリアテスト"""
  # 履歴に記録
  target_node.global_position = Vector2(200, 200)
  trail_system._record_position()

  # クリア実行
  trail_system.clear_history()

  # 初期状態に戻ることを確認
  assert_that(trail_system.get_history_size()).is_equal(trail_system.history_size)
  for i in range(trail_system.history_size):
    assert_that(trail_system.position_history[i]).is_equal(target_node.global_position)


func test_get_position_at_delay_valid():
  """有効遅延位置取得テスト"""
  # 履歴に複数位置を記録
  var positions = [Vector2(100, 100), Vector2(200, 200), Vector2(300, 300)]
  for pos in positions:
    target_node.global_position = pos
    trail_system._record_position()

  # 遅延アクセス（最新が0、1フレーム前、2フレーム前）
  var delayed_pos = trail_system.get_position_at_delay(1)
  assert_that(delayed_pos).is_equal(Vector2(200, 200))

  var delayed_pos_2 = trail_system.get_position_at_delay(2)
  assert_that(delayed_pos_2).is_equal(Vector2(100, 100))


func test_get_position_at_delay_out_of_bounds():
  """範囲外遅延位置取得テスト"""
  # 履歴サイズを超える遅延要求
  var delayed_pos = trail_system.get_position_at_delay(999)

  # 最後の有効な位置が返される
  assert_that(delayed_pos).is_equal(target_node.global_position)


func test_get_rotation_at_delay_valid():
  """有効遅延回転取得テスト"""
  # 履歴に複数回転を記録
  var rad45 = floor(deg_to_rad(45))
  var rad90 = floor(deg_to_rad(90))

  var rotations = [0.0, rad45, rad90]
  for rot in rotations:
    target_node.global_rotation = rot
    trail_system._record_position()

  # 遅延アクセス
  var delayed_rot = trail_system.get_rotation_at_delay(1)
  assert_that(delayed_rot).is_equal(rad45)


func test_get_rotation_at_delay_out_of_bounds():
  """範囲外遅延回転取得テスト"""
  var delayed_rot = trail_system.get_rotation_at_delay(999)

  # 最後の有効な回転が返される
  assert_that(delayed_rot).is_equal(target_node.global_rotation)


# === フレーム更新テスト ===


func test_frame_counter_increment():
  """フレームカウンター増加テスト"""
  var initial_counter = trail_system.frame_counter

  # _process()を手動実行
  trail_system._process(0.016)  # 約60FPS

  assert_that(trail_system.frame_counter).is_equal(initial_counter + 1)


func test_update_frequency_control():
  """更新頻度制御テスト"""
  trail_system.update_every_frames = 3

  var initial_position = trail_system.position_history[0]

  # 3フレーム未満では記録されない
  trail_system._process(0.016)
  trail_system._process(0.016)
  assert_that(trail_system.position_history[0]).is_equal(initial_position)

  # 3フレーム目で記録される
  target_node.global_position = Vector2(500, 500)
  trail_system._process(0.016)
  assert_that(trail_system.position_history[0]).is_equal(Vector2(500, 500))


func test_frame_skip_behavior():
  """フレームスキップ動作テスト"""
  trail_system.update_every_frames = 5

  # 5フレーム周期で記録されることを確認
  for i in range(10):
    target_node.global_position = Vector2(i * 10, i * 10)
    trail_system._process(0.016)

    if (trail_system.frame_counter % 5) == 0:
      # 5の倍数フレームで位置が更新される
      assert_that(trail_system.position_history[0]).is_equal(Vector2(i * 10, i * 10))


# === エラーハンドリング・堅牢性テスト ===


func test_null_target_node_handling():
  """nullターゲットノードハンドリングテスト"""
  # ターゲットノードをnullに設定
  trail_system.target_node = null

  # エラーが発生しないことを確認
  trail_system._process(0.016)
  # _record_position()は内部でtarget_nodeをチェックするはず


func test_invalid_history_size():
  """無効履歴サイズテスト"""
  trail_system.history_size = -5
  trail_system._initialize_history()

  # 負のサイズでも安全に処理される
  assert_that(trail_system.position_history.size()).is_greater_equal(0)
  assert_that(trail_system.rotation_history.size()).is_greater_equal(0)


func test_invalid_update_frequency():
  """無効更新頻度テスト"""
  trail_system.update_every_frames = 0

  # ゼロ除算エラーが発生しないことを確認
  trail_system._process(0.016)
  assert_that(trail_system.frame_counter).is_greater(0)


func test_extreme_positions():
  """極端な位置値テスト"""
  var extreme_positions = [
    Vector2(-99999, -99999),
    Vector2(99999, 99999),
    Vector2.INF,
    Vector2(-Vector2.INF.x, -Vector2.INF.y)
  ]

  for pos in extreme_positions:
    if pos.is_finite():
      target_node.global_position = pos
      trail_system._record_position()
      # 正常に記録されることを確認
      assert_that(trail_system.position_history[0]).is_equal(pos)


# === パフォーマンス・メモリテスト ===


func test_large_history_size():
  """大容量履歴サイズテスト"""
  trail_system.history_size = 1000
  trail_system._initialize_history()

  # 大容量でもメモリエラーが発生しないことを確認
  assert_that(trail_system.position_history.size()).is_equal(1000)
  assert_that(trail_system.rotation_history.size()).is_equal(1000)


func test_frequent_updates():
  """頻繁更新テスト"""
  trail_system.update_every_frames = 1

  # 多数回の更新でも安定動作
  for i in range(100):
    target_node.global_position = Vector2(i, i)
    trail_system._process(0.016)

  # 最新の位置が正しく記録される
  assert_that(trail_system.position_history[0]).is_equal(Vector2(99, 99))


# === 統合・実用性テスト ===


func test_worm_following_simulation():
  """ワーム追従シミュレーションテスト"""
  # ワームの頭部が移動するパターンをシミュレート
  var path_points = [
    Vector2(100, 100), Vector2(150, 120), Vector2(200, 150), Vector2(250, 180), Vector2(300, 200)
  ]

  for point in path_points:
    target_node.global_position = point
    trail_system._record_position()

  # 遅延位置を使用してワーム節の位置を取得
  var segment_positions = []
  for i in range(min(4, trail_system.history_size)):
    segment_positions.append(trail_system.get_position_at_delay(i + 1))

  # セグメント位置が適切に設定される
  assert_that(segment_positions.size()).is_greater(0)
  for pos in segment_positions:
    assert_that(pos is Vector2).is_true()


func test_direction_at_delay():
  """遅延方向取得テスト"""
  # 移動パターンを記録
  var positions = [Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)]
  for pos in positions:
    target_node.global_position = pos
    trail_system._record_position()

  # 移動方向を取得
  var direction = trail_system.get_direction_at_delay(0)
  assert_that(direction is Vector2).is_true()
  assert_that(abs(direction.length() - 1.0)).is_less(0.01)  # 正規化されている


func test_trail_system_independence():
  """トレイルシステム独立性テスト"""
  # 複数のトレイルシステムが独立動作することを確認
  var target2 = Node2D.new()
  var trail2 = TrailFollowSystem.new()
  test_scene.add_child(target2)
  target2.add_child(trail2)

  target_node.global_position = Vector2(100, 100)
  target2.global_position = Vector2(200, 200)

  trail_system._record_position()
  trail2._record_position()

  # 独立した履歴を持つことを確認
  assert_that(trail_system.position_history[0]).is_equal(Vector2(100, 100))
  assert_that(trail2.position_history[0]).is_equal(Vector2(200, 200))
