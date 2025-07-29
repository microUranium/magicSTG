extends Node

@export var hud_width := 384  # HUD の横幅を 1 箇所で集中管理
static var _play_rect: Rect2  # キャッシュ


func _ready() -> void:
  _update_rect()
  get_viewport().size_changed.connect(_update_rect)


func _update_rect() -> void:
  var vp := get_viewport().get_visible_rect()
  _play_rect = Rect2(vp.position, Vector2(vp.size.x - hud_width, vp.size.y))
  print_debug("PlayArea: Updated play rect to %s" % _play_rect)


static func get_play_rect() -> Rect2:
  return _play_rect
