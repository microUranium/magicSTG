extends Area2D
class_name DroppedItem

var item_instance: ItemInstance
var player: Player
var speed: float = 100.0  # プレイヤーに向かう速度

## ItemInstance.RarityTier の値をインデックスとしたレアリティ別スプライト
@export var item_images_blessing: Array[Texture2D] = []
@export var item_images_core: Array[Texture2D] = []
@onready var sprite := $Sprite2D


func _ready() -> void:
  connect("area_entered", Callable(self, "_on_area_entered"))
  if item_instance.prototype.item_type == item_instance.prototype.ItemType.BLESSING:
    sprite.texture = _pick_texture(item_images_blessing, item_instance.get_rarity_tier())
  else:
    sprite.texture = _pick_texture(item_images_core, item_instance.get_rarity_tier())

  # ランダムな方向に向かって少し移動
  var angle: float = randf() * 2 * PI
  speed = 50
  var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed
  var tw := create_tween()
  tw.tween_property(self, "position", position + velocity, 0.5)
  tw.set_ease(Tween.EASE_IN_OUT)
  tw.play()

  # 0.5秒後にプレイヤーに向かって移動
  await get_tree().create_timer(0.5, false).timeout
  player = TargetService.get_player()
  speed = 300  # プレイヤーに向かう速度を設定
  # 徐々に加速
  var acceleration: float = 1000.0  # 加速量
  var tw_accel := create_tween()
  tw_accel.tween_property(self, "speed", speed + acceleration, 1.5)
  tw_accel.set_ease(Tween.EASE_IN_OUT)
  tw_accel.play()


func _process(delta: float) -> void:
  if is_instance_valid(player):
    var direction: Vector2 = (player.global_position - global_position).normalized()
    position += direction * speed * delta  # プレイヤーに向かって移動


## 指定ティアのスプライトを返す。未設定の場合はそれ以下で最も高いティアのものを使う
func _pick_texture(textures: Array[Texture2D], tier: int) -> Texture2D:
  for i in range(min(tier, textures.size() - 1), -1, -1):
    if textures[i]:
      return textures[i]
  return null


func _on_area_entered(body: Node) -> void:
  if body is Player:
    Ephemeralnventory.add(item_instance)
    StageSignals.emit_signal("sfx_play_requested", "get_item", global_position, 0, 0)
    queue_free()
