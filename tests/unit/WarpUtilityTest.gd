# WarpUtility のテスト
extends GdUnitTestSuite
class_name WarpUtilityTest


func test_calculate_behind_position_basic():
  """基本的な背後座標計算のテスト"""
  var player_pos = Vector2(400, 300)
  var player_facing = Vector2.DOWN  # 下向き
  var distance_range = Vector2(100, 150)
  var angle_variation = 0.0  # 揺らぎなし

  var result = WarpUtility.calculate_behind_position(
    player_pos, player_facing, distance_range, angle_variation
  )

  # 下向きの場合、背後は上方向（プレイヤーの上側）
  assert_that(result.y).is_greater(player_pos.y)
  assert_that(result.x).is_equal(player_pos.x)

  # 距離は指定範囲内
  var distance = player_pos.distance_to(result)
  assert_that(distance).is_greater_equal(distance_range.x)
  assert_that(distance).is_less_equal(distance_range.y)


func test_calculate_behind_position_with_angle_variation():
  """角度揺らぎありの背後座標計算のテスト"""
  var player_pos = Vector2(400, 300)
  var player_facing = Vector2.DOWN
  var distance_range = Vector2(100, 100)  # 固定距離
  var angle_variation = 45.0  # ±45度の揺らぎ

  # 複数回実行して揺らぎを確認
  var positions = []
  for i in range(10):
    var result = WarpUtility.calculate_behind_position(
      player_pos, player_facing, distance_range, angle_variation
    )
    positions.append(result)

  # すべて異なる座標になることを確認（揺らぎがあるため）
  var unique_positions = {}
  for pos in positions:
    unique_positions[str(pos)] = true

  # 最低でも3つ以上は異なる座標が生成されることを期待
  assert_that(unique_positions.size()).is_greater(3)


func test_calculate_behind_position_different_facing_directions():
  """異なる向きでの背後座標計算のテスト"""
  var player_pos = Vector2(400, 300)
  var distance_range = Vector2(100, 100)
  var angle_variation = 0.0

  # 上向きの場合
  var result_up = WarpUtility.calculate_behind_position(
    player_pos, Vector2.UP, distance_range, angle_variation
  )
  assert_that(result_up.y).is_less(player_pos.y)  # 背後は下

  # 右向きの場合
  var result_right = WarpUtility.calculate_behind_position(
    player_pos, Vector2.RIGHT, distance_range, angle_variation
  )
  assert_that(result_right.x).is_greater(player_pos.x)  # 背後は左

  # 左向きの場合
  var result_left = WarpUtility.calculate_behind_position(
    player_pos, Vector2.LEFT, distance_range, angle_variation
  )
  assert_that(result_left.x).is_less(player_pos.x)  # 背後は右


func test_clamp_to_play_area():
  """PlayArea境界内へのクランプのテスト"""
  var margin = 50.0
  var play_rect = PlayArea.get_play_rect()

  # 境界外の座標をテスト
  var outside_pos = Vector2(-100, -100)
  var clamped = WarpUtility.clamp_to_play_area(outside_pos)

  assert_that(clamped.x).is_equal(play_rect.position.x + margin)
  assert_that(clamped.y).is_equal(play_rect.position.y + margin)

  # 右下境界外
  outside_pos = Vector2(play_rect.size.x + 100, play_rect.size.y + 100)
  clamped = WarpUtility.clamp_to_play_area(outside_pos)

  assert_that(clamped.x).is_equal(play_rect.position.x + play_rect.size.x - margin)
  assert_that(clamped.y).is_equal(play_rect.position.y + play_rect.size.y - margin)


func test_clamp_to_play_area_inside_bounds():
  """境界内の座標はそのまま返されることのテスト"""
  var inside_pos = Vector2(400, 300)
  var result = WarpUtility.clamp_to_play_area(inside_pos)

  assert_that(result).is_equal(inside_pos)


func test_is_valid_position():
  """有効座標判定のテスト"""
  var margin = 30.0
  var play_rect = PlayArea.get_play_rect()

  # 有効な座標
  var valid_pos = Vector2(400, 300)
  assert_that(WarpUtility.is_valid_position(valid_pos)).is_true()

  # 境界に近い有効な座標
  var edge_valid = Vector2(play_rect.position.x + margin + 1, play_rect.position.y + margin + 1)
  assert_that(WarpUtility.is_valid_position(edge_valid)).is_true()

  # 無効な座標（境界外）
  var invalid_pos = Vector2(play_rect.position.x + margin - 1, play_rect.position.y + margin - 1)
  assert_that(WarpUtility.is_valid_position(invalid_pos)).is_false()

  # 右下境界外
  invalid_pos = Vector2(
    play_rect.position.x + play_rect.size.x - margin + 1,
    play_rect.position.y + play_rect.size.y - margin + 1
  )
  assert_that(WarpUtility.is_valid_position(invalid_pos)).is_false()


func test_create_warp_effect_null_scene():
  """nullシーンでのエフェクト生成のテスト"""
  # nullを渡してもエラーが出ないことを確認
  WarpUtility.create_warp_effect(null, Vector2.ZERO, 1.0)
  # エラーが出なければ成功


func test_calculate_behind_position_zero_distance():
  """距離が0の場合のテスト"""
  var player_pos = Vector2(400, 300)
  var player_facing = Vector2.DOWN
  var distance_range = Vector2(0, 0)
  var angle_variation = 0.0

  var result = WarpUtility.calculate_behind_position(
    player_pos, player_facing, distance_range, angle_variation
  )

  # 距離が0なので、プレイヤー位置と同じになる（クランプ後）
  var distance = player_pos.distance_to(result)
  assert_that(distance).is_equal(0.0)


func test_calculate_behind_position_large_distance():
  """大きな距離での境界クランプのテスト"""
  var player_pos = Vector2(400, 300)
  var player_facing = Vector2.DOWN
  var distance_range = Vector2(1000, 1000)  # PlayAreaを超える距離
  var angle_variation = 0.0

  var result = WarpUtility.calculate_behind_position(
    player_pos, player_facing, distance_range, angle_variation
  )

  # 結果は必ずPlayArea内にクランプされる
  assert_that(WarpUtility.is_valid_position(result)).is_true()


func test_calculate_behind_position_angle_precision():
  """角度計算の精度テスト"""
  var player_pos = Vector2(400, 300)
  var distance_range = Vector2(100, 100)
  var angle_variation = 0.0  # 揺らぎなし

  # 各基本方向での背後計算
  var test_cases = [
    {"facing": Vector2.DOWN, "expected_behind": Vector2.DOWN},
    {"facing": Vector2.UP, "expected_behind": Vector2.UP},
    {"facing": Vector2.RIGHT, "expected_behind": Vector2.RIGHT},
    {"facing": Vector2.LEFT, "expected_behind": Vector2.LEFT}
  ]

  for case in test_cases:
    var result = WarpUtility.calculate_behind_position(
      player_pos, case.facing, distance_range, angle_variation
    )

    var actual_direction = (result - player_pos).normalized()
    var dot_product = actual_direction.dot(case.expected_behind)

    # ドット積が1に近い（同じ方向）ことを確認
    assert_that(dot_product).is_greater(0.9)


func test_calculate_behind_position_angle_variation_range():
  """角度揺らぎの範囲テスト"""
  var player_pos = Vector2(400, 300)
  var player_facing = Vector2.DOWN
  var distance_range = Vector2(100, 100)
  var angle_variation = 30.0  # ±30度

  var min_angle = player_facing.angle() - deg_to_rad(angle_variation)
  var max_angle = player_facing.angle() + deg_to_rad(angle_variation)

  # 複数回実行して全て範囲内であることを確認
  for i in range(20):
    var result = WarpUtility.calculate_behind_position(
      player_pos, player_facing, distance_range, angle_variation
    )

    var direction = (result - player_pos).normalized()
    var angle = direction.angle()

    # 角度を -PI から PI の範囲に正規化
    while angle > PI:
      angle -= TAU
    while angle < -PI:
      angle += TAU

    var normalized_min = min_angle
    var normalized_max = max_angle
    while normalized_min > PI:
      normalized_min -= TAU
    while normalized_min < -PI:
      normalized_min += TAU
    while normalized_max > PI:
      normalized_max -= TAU
    while normalized_max < -PI:
      normalized_max += TAU

    # 角度が範囲内にあることを確認
    if normalized_min <= normalized_max:
      assert_that(angle).is_greater_equal(normalized_min)
      assert_that(angle).is_less_equal(normalized_max)
    else:
      # 範囲が -PI を跨ぐ場合
      var in_range = (angle >= normalized_min) or (angle <= normalized_max)
      assert_that(in_range).is_true()
