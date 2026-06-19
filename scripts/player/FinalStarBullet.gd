extends UniversalBullet
class_name FinalStarBullet

@export var center_destroy_radius: float = 30.0


func _process(delta):
  super._process(delta)

  # ステージ中心付近に到達したら弾を削除
  @warning_ignore("static_called_on_instance") var play_rect := PlayArea.get_play_rect()
  var center := play_rect.get_center()
  if global_position.distance_to(center) <= center_destroy_radius:
    _immediate_removal()
