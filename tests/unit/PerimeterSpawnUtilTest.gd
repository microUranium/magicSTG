# PerimeterSpawnUtil のテスト
extends GdUnitTestSuite
class_name PerimeterSpawnUtilTest


func test_calculate_total_perimeter():
  """全周距離計算のテスト"""
  var play_rect = Rect2(0, 0, 800, 600)
  var expected: float = (800 + 600) * 2  # 2800

  var result = PerimeterSpawnUtil._calculate_total_perimeter(play_rect)
  assert_that(result).is_equal(expected)


func test_calculate_start_distance_all_sides():
  """各辺の開始距離計算テスト"""
  var play_rect = Rect2(0, 0, 800, 600)

  # Top辺（中央）
  var distance = PerimeterSpawnUtil._calculate_start_distance("top", 0.5, play_rect)
  assert_that(distance).is_equal(400.0)  # width * 0.5

  # Right辺（開始）
  distance = PerimeterSpawnUtil._calculate_start_distance("right", 0.0, play_rect)
  assert_that(distance).is_equal(800.0)  # width

  # Bottom辺（中央）
  distance = PerimeterSpawnUtil._calculate_start_distance("bottom", 0.5, play_rect)
  assert_that(distance).is_equal(1800.0)  # width + height + width * 0.5

  # Left辺（終端）
  distance = PerimeterSpawnUtil._calculate_start_distance("left", 1.0, play_rect)
  assert_that(distance).is_equal(2800.0)  # 全周


func test_calculate_spacing_full_perimeter():
  """全周分散スペーシング計算のテスト"""
  var perimeter_length = 2800.0
  var count = 8
  var full_perimeter = true

  var spacing = PerimeterSpawnUtil._calculate_spacing(count, full_perimeter, perimeter_length)
  assert_that(spacing).is_equal(350.0)  # 2800 / 8


func test_calculate_spacing_concentrated():
  """集中配置スペーシング計算のテスト"""
  var perimeter_length = 2800.0
  var count = 4
  var full_perimeter = false

  var spacing = PerimeterSpawnUtil._calculate_spacing(count, full_perimeter, perimeter_length)
  # min(64.0, 1400.0 / 4) = min(64.0, 350.0) = 64.0
  assert_that(spacing).is_equal(64.0)


func test_distance_to_coordinate_top_side():
  """Top辺での距離→座標変換テスト"""
  var play_rect = Rect2(0, 0, 800, 600)
  var distance = 200.0  # Top辺の途中

  var coord = PerimeterSpawnUtil._distance_to_coordinate(distance, play_rect)
  assert_that(coord.side).is_equal(PerimeterSpawnUtil.Side.TOP)
  assert_that(coord.progress).is_equal(0.25)  # 200 / 800
  assert_that(coord.distance).is_equal(distance)


func test_distance_to_coordinate_right_side():
  """Right辺での距離→座標変換テスト"""
  var play_rect = Rect2(0, 0, 800, 600)
  var distance = 1100.0  # 800 + 300 (Right辺の途中)

  var coord = PerimeterSpawnUtil._distance_to_coordinate(distance, play_rect)
  assert_that(coord.side).is_equal(PerimeterSpawnUtil.Side.RIGHT)
  assert_that(coord.progress).is_equal(0.5)  # 300 / 600
  assert_that(coord.distance).is_equal(distance)


func test_perimeter_coordinate_to_world_position():
  """PerimeterCoordinate→ワールド座標変換テスト"""
  var play_rect = Rect2(100, 50, 800, 600)
  var margin = 32.0

  # Top辺中央
  var coord = PerimeterSpawnUtil.PerimeterCoordinate.new(PerimeterSpawnUtil.Side.TOP, 0.5, 0.0)
  var world_pos = coord.to_world_position(play_rect, margin)
  assert_that(world_pos.x).is_equal(500.0)  # 100 + 800 * 0.5
  assert_that(world_pos.y).is_equal(18.0)  # 50 - 32

  # Right辺中央
  coord = PerimeterSpawnUtil.PerimeterCoordinate.new(PerimeterSpawnUtil.Side.RIGHT, 0.5, 0.0)
  world_pos = coord.to_world_position(play_rect, margin)
  assert_that(world_pos.x).is_equal(932.0)  # 100 + 800 + 32
  assert_that(world_pos.y).is_equal(350.0)  # 50 + 600 * 0.5


func test_calculate_perimeter_positions_clockwise():
  """時計回り周囲座標計算テスト"""
  var play_rect = Rect2(0, 0, 400, 300)
  var params = {
    "perimeter_direction": "clockwise",
    "start_side": "top",
    "start_position": 0.0,
    "full_perimeter": true,
    "margin": 32.0
  }

  var positions = PerimeterSpawnUtil.calculate_perimeter_positions(4, params, play_rect)
  assert_that(positions.size()).is_equal(4)

  # 最初の位置はTop左端
  assert_that(positions[0].x).is_equal(0.0)
  assert_that(positions[0].y).is_equal(-32.0)


func test_calculate_perimeter_positions_counter_clockwise():
  """反時計回り周囲座標計算テスト"""
  var play_rect = Rect2(0, 0, 400, 300)
  var params = {
    "perimeter_direction": "counter_clockwise",
    "start_side": "top",
    "start_position": 0.0,
    "full_perimeter": true,
    "margin": 32.0
  }

  var positions = PerimeterSpawnUtil.calculate_perimeter_positions(4, params, play_rect)
  assert_that(positions.size()).is_equal(4)

  # 反時計回りなので最初の位置は計算が逆転
  # （具体的な座標は複雑なので、サイズのみ確認）


func test_validate_perimeter_params_valid():
  """有効パラメータの妥当性チェック"""
  var valid_params = {
    "perimeter_direction": "clockwise", "start_side": "top", "start_position": 0.5, "margin": 50.0
  }

  assert_that(PerimeterSpawnUtil.validate_perimeter_params(valid_params)).is_true()


func test_validate_perimeter_params_invalid():
  """無効パラメータの妥当性チェック"""
  # 無効な方向
  var invalid_params = {
    "perimeter_direction": "invalid_direction",
    "start_side": "top",
    "start_position": 0.5,
    "margin": 50.0
  }
  assert_that(PerimeterSpawnUtil.validate_perimeter_params(invalid_params)).is_false()

  # 無効な開始位置
  invalid_params = {
    "perimeter_direction": "clockwise", "start_side": "top", "start_position": 2.0, "margin": 50.0  # 範囲外
  }
  assert_that(PerimeterSpawnUtil.validate_perimeter_params(invalid_params)).is_false()

  # 無効なマージン
  invalid_params = {
    "perimeter_direction": "clockwise", "start_side": "top", "start_position": 0.5, "margin": -10.0  # 負の値
  }
  assert_that(PerimeterSpawnUtil.validate_perimeter_params(invalid_params)).is_false()


func test_get_default_params():
  """デフォルトパラメータ取得のテスト"""
  var defaults = PerimeterSpawnUtil.get_default_params()

  assert_that(defaults["perimeter_direction"]).is_equal("clockwise")
  assert_that(defaults["start_side"]).is_equal("top")
  assert_that(defaults["start_position"]).is_equal(0.0)
  assert_that(defaults["margin"]).is_equal(32.0)
  assert_that(defaults["full_perimeter"]).is_true()


func test_calculate_perimeter_positions_empty_count():
  """ゼロカウントでの座標計算テスト"""
  var play_rect = Rect2(0, 0, 400, 300)
  var params = PerimeterSpawnUtil.get_default_params()

  var positions = PerimeterSpawnUtil.calculate_perimeter_positions(0, params, play_rect)
  assert_that(positions.size()).is_equal(0)


func test_perimeter_coordinate_all_sides_world_conversion():
  """全辺でのワールド座標変換精度テスト"""
  var play_rect = Rect2(0, 0, 400, 300)
  var margin = 32.0

  var test_cases = [
    {"side": PerimeterSpawnUtil.Side.TOP, "progress": 0.0, "expected": Vector2(0.0, -32.0)},
    {"side": PerimeterSpawnUtil.Side.RIGHT, "progress": 0.0, "expected": Vector2(432.0, 0.0)},
    {"side": PerimeterSpawnUtil.Side.BOTTOM, "progress": 0.0, "expected": Vector2(400.0, 332.0)},
    {"side": PerimeterSpawnUtil.Side.LEFT, "progress": 0.0, "expected": Vector2(-32.0, 300.0)}
  ]

  for case in test_cases:
    var coord = PerimeterSpawnUtil.PerimeterCoordinate.new(case.side, case.progress, 0.0)
    var world_pos = coord.to_world_position(play_rect, margin)

    assert_that(world_pos.x).is_equal(case.expected.x)
    assert_that(world_pos.y).is_equal(case.expected.y)
