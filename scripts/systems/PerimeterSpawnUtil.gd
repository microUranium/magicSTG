# PlayArea周囲座標の計算ユーティリティ
class_name PerimeterSpawnUtil

enum Side { TOP, RIGHT, BOTTOM, LEFT }


# 周囲座標データ
class PerimeterCoordinate:
  var side: PerimeterSpawnUtil.Side
  var progress: float  # 0.0-1.0 辺上での位置
  var distance: float  # 累積周囲距離

  func _init(s: PerimeterSpawnUtil.Side, p: float, d: float):
    side = s
    progress = p
    distance = d

  # 実際のワールド座標に変換
  func to_world_position(play_rect: Rect2, margin: float) -> Vector2:
    match side:
      Side.TOP:
        var x = play_rect.position.x + play_rect.size.x * progress
        return Vector2(x, play_rect.position.y - margin)
      Side.RIGHT:
        var y = play_rect.position.y + play_rect.size.y * progress
        return Vector2(play_rect.position.x + play_rect.size.x + margin, y)
      Side.BOTTOM:
        var x = play_rect.position.x + play_rect.size.x * (1.0 - progress)
        return Vector2(x, play_rect.position.y + play_rect.size.y + margin)
      Side.LEFT:
        var y = play_rect.position.y + play_rect.size.y * (1.0 - progress)
        return Vector2(play_rect.position.x - margin, y)
      _:
        return Vector2.ZERO


# PlayArea周囲にスポーン座標を計算
static func calculate_perimeter_positions(
  count: int, params: Dictionary, play_rect: Rect2
) -> Array[Vector2]:
  if count <= 0:
    return []

  var margin = params.get("margin", 32.0)
  var direction = params.get("perimeter_direction", "clockwise")
  var start_side = params.get("start_side", "top")
  var start_position = params.get("start_position", 0.0)
  var full_perimeter = params.get("full_perimeter", true)

  # 全周距離計算
  var perimeter_length = _calculate_total_perimeter(play_rect)

  # 開始距離計算
  var start_distance = _calculate_start_distance(start_side, start_position, play_rect)

  # スポーン間隔計算
  var spacing = _calculate_spacing(count, full_perimeter, perimeter_length)

  # 各敵の座標を計算
  var positions: Array[Vector2] = []
  for i in range(count):
    var distance = start_distance + (spacing * i)

    # 反時計回りの場合は距離を反転
    if direction == "counter_clockwise":
      distance = perimeter_length - distance

    # 周囲をループ
    distance = fmod(distance, perimeter_length)
    if distance < 0:
      distance += perimeter_length

    var coord = _distance_to_coordinate(distance, play_rect)
    var world_pos = coord.to_world_position(play_rect, margin)
    positions.append(world_pos)

  return positions


# 全周の距離を計算
static func _calculate_total_perimeter(play_rect: Rect2) -> float:
  return (play_rect.size.x + play_rect.size.y) * 2.0


# 開始辺と位置から開始距離を計算
static func _calculate_start_distance(
  start_side: String, start_position: float, play_rect: Rect2
) -> float:
  var clamped_pos = clamp(start_position, 0.0, 1.0)

  match start_side:
    "top":
      return play_rect.size.x * clamped_pos
    "right":
      return play_rect.size.x + (play_rect.size.y * clamped_pos)
    "bottom":
      return play_rect.size.x + play_rect.size.y + (play_rect.size.x * clamped_pos)
    "left":
      return (play_rect.size.x * 2) + play_rect.size.y + (play_rect.size.y * clamped_pos)
    _:
      return 0.0


# スポーン間隔を計算
static func _calculate_spacing(count: int, full_perimeter: bool, perimeter_length: float) -> float:
  if full_perimeter:
    # 全周に均等分散
    return perimeter_length / float(count)
  else:
    # 集中配置モード（最大半周）
    var max_arc_length = perimeter_length * 0.5
    return min(64.0, max_arc_length / float(count))


# 累積距離から周囲座標に変換
static func _distance_to_coordinate(distance: float, play_rect: Rect2) -> PerimeterCoordinate:
  var width = play_rect.size.x
  var height = play_rect.size.y

  # 各辺の境界距離
  var top_end = width
  var right_end = width + height
  var bottom_end = width + height + width
  var left_end = width + height + width + height

  if distance <= top_end:
    # Top辺
    var progress = distance / width
    return PerimeterCoordinate.new(Side.TOP, progress, distance)
  elif distance <= right_end:
    # Right辺
    var progress = (distance - top_end) / height
    return PerimeterCoordinate.new(Side.RIGHT, progress, distance)
  elif distance <= bottom_end:
    # Bottom辺
    var progress = (distance - right_end) / width
    return PerimeterCoordinate.new(Side.BOTTOM, progress, distance)
  else:
    # Left辺
    var progress = (distance - bottom_end) / height
    return PerimeterCoordinate.new(Side.LEFT, progress, distance)


# 周囲座標の妥当性チェック
static func validate_perimeter_params(params: Dictionary) -> bool:
  var valid_directions = ["clockwise", "counter_clockwise"]
  var valid_sides = ["top", "right", "bottom", "left"]

  var direction = params.get("perimeter_direction", "clockwise")
  var start_side = params.get("start_side", "top")
  var start_position = params.get("start_position", 0.0)
  var margin = params.get("margin", 32.0)

  return (
    direction in valid_directions
    and start_side in valid_sides
    and start_position >= 0.0
    and start_position <= 1.0
    and margin > 0.0
  )


# デフォルトパラメータを取得
static func get_default_params() -> Dictionary:
  return {
    "perimeter_direction": "clockwise",
    "start_side": "top",
    "start_position": 0.0,
    "margin": 32.0,
    "full_perimeter": true
  }
