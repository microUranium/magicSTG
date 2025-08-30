# ワープ機能の汎用ユーティリティクラス
class_name WarpUtility


# プレイヤーの背後座標を計算（揺らぎ付き）
static func calculate_behind_position(
  player_pos: Vector2, player_facing: Vector2, distance_range: Vector2, angle_variation: float  # x=min, y=max  # ±度の揺らぎ
) -> Vector2:
  # プレイヤーの向きが基準
  var base_angle = player_facing.angle()

  # 角度に揺らぎを追加
  var angle_offset = randf_range(-deg_to_rad(angle_variation), deg_to_rad(angle_variation))
  var final_angle = base_angle + angle_offset

  # 距離に揺らぎを追加
  var distance = randf_range(distance_range.x, distance_range.y)

  # 最終座標計算
  var offset = Vector2.from_angle(final_angle) * distance
  var result = player_pos + offset

  # PlayArea境界内にクランプ
  return clamp_to_play_area(result)


# 座標をPlayArea境界内にクランプ
static func clamp_to_play_area(pos: Vector2) -> Vector2:
  var play_rect = PlayArea.get_play_rect()
  var margin = 50.0  # 境界からのマージン
  return Vector2(
    clamp(pos.x, play_rect.position.x + margin, play_rect.position.x + play_rect.size.x - margin),
    clamp(pos.y, play_rect.position.y + margin, play_rect.position.y + play_rect.size.y - margin)
  )


# ワープエフェクトを生成し、指定時間後に自動削除
static func create_warp_effect(
  effect_scene: PackedScene, position: Vector2, duration: float
) -> void:
  if not effect_scene:
    return

  var effect = effect_scene.instantiate()
  var scene_root = Engine.get_main_loop().current_scene
  scene_root.add_child(effect)
  effect.global_position = position

  var particles = effect.get_node_or_null("GPUParticles2D")
  if particles:
    particles.restart()

  # duration後に自動削除
  var timer = Timer.new()
  scene_root.add_child(timer)
  timer.wait_time = duration
  timer.one_shot = true
  timer.timeout.connect(
    func():
      if is_instance_valid(effect):
        effect.queue_free()
      timer.queue_free()
  )
  timer.start()


# 座標が有効（PlayArea内）かどうかをチェック
static func is_valid_position(pos: Vector2) -> bool:
  var play_rect = PlayArea.get_play_rect()
  var margin = 30.0
  return (
    pos.x >= play_rect.position.x + margin
    and pos.x <= play_rect.position.x + play_rect.size.x - margin
    and pos.y >= play_rect.position.y + margin
    and pos.y <= play_rect.position.y + play_rect.size.y - margin
  )
