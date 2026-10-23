extends Area2D
class_name DroppedItem

var item_instance: ItemInstance
var player: Player
var speed: float = 100.0  # プレイヤーに向かう速度

const DEFAULT_HOMING_DELAY_SEC := 0.5  # プレイヤーに吸い寄せられ始めるまでの時間
const DRIFT_INITIAL_SPEED := 200.0  # 出現直後に散らばる速度
const DRIFT_DECEL_SEC := 0.8  # 散らばる速度が drift_min_speed まで落ちるまでの時間

## ItemInstance.RarityTier の値をインデックスとしたレアリティ別スプライト
@export var item_images_blessing: Array[Texture2D] = []
@export var item_images_core: Array[Texture2D] = []
## ItemInstance.RarityTier の値をインデックスとしたレアリティ別演出（null なら演出なし）
@export var rarity_effect_scenes: Array[PackedScene] = []
## ItemInstance.RarityTier の値をインデックスとした、吸い寄せ開始までの秒数（未設定なら DEFAULT_HOMING_DELAY_SEC）
## 高レアリティほど長くして出現演出を見せる
@export var homing_delay_sec_by_tier: Array[float] = []
## 吸い寄せが始まるまで、散らばった方向へ移動し続ける最低速度（止まって見えないようにする）
@export var drift_min_speed: float = 20.0
@onready var sprite := $Sprite2D

var _rarity_effect: Node2D
var _drift_direction: Vector2 = Vector2.ZERO
var _drift_speed: float = 0.0


func _ready() -> void:
  connect("area_entered", Callable(self, "_on_area_entered"))
  if item_instance.prototype.item_type == item_instance.prototype.ItemType.BLESSING:
    sprite.texture = _pick_texture(item_images_blessing, item_instance.get_rarity_tier())
  else:
    sprite.texture = _pick_texture(item_images_core, item_instance.get_rarity_tier())
  _spawn_rarity_effect(item_instance.get_rarity_tier())

  # ランダムな方向に散らばり、減速しながら吸い寄せ開始まで最低速度で移動し続ける
  _drift_direction = Vector2.from_angle(randf() * TAU)
  _drift_speed = DRIFT_INITIAL_SPEED
  var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
  tw.tween_property(self, "_drift_speed", drift_min_speed, DRIFT_DECEL_SEC)

  # 一定時間後にプレイヤーに向かって移動
  await get_tree().create_timer(_get_homing_delay(item_instance.get_rarity_tier()), false).timeout
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
  else:
    position += _drift_direction * _drift_speed * delta


## 指定ティアのスプライトを返す。未設定の場合はそれ以下で最も高いティアのものを使う
func _pick_texture(textures: Array[Texture2D], tier: int) -> Texture2D:
  for i in range(min(tier, textures.size() - 1), -1, -1):
    if textures[i]:
      return textures[i]
  return null


func _get_homing_delay(tier: int) -> float:
  if tier < homing_delay_sec_by_tier.size():
    return homing_delay_sec_by_tier[tier]
  return DEFAULT_HOMING_DELAY_SEC


func _spawn_rarity_effect(tier: int) -> void:
  if tier >= rarity_effect_scenes.size() or rarity_effect_scenes[tier] == null:
    return
  _rarity_effect = rarity_effect_scenes[tier].instantiate()
  add_child(_rarity_effect)
  move_child(_rarity_effect, 0)  # アイテムのスプライトより背面に描画する


func _on_area_entered(body: Node) -> void:
  if body is Player:
    Ephemeralnventory.add(item_instance)
    StageSignals.emit_signal("sfx_play_requested", "get_item", global_position, 0, 0)
    if _rarity_effect:
      _rarity_effect.play_pickup()
    queue_free()
