extends Node2D
class_name DamageNumber

## 被弾ダメージを表示するデバッグ用フローティングテキスト。
## 被弾側（EnemyBase など）から DamageNumber.spawn() で生成する。
## 少し上へ移動 → 短時間停止 → フェードアウトして自動削除される。

const RISE_DISTANCE: float = 40.0  # 上方向へ移動する距離(px)。正の値で上へ、負の値で下へ移動
const RISE_TIME: float = 0.6  # 上昇にかける時間(秒)
const HOLD_TIME: float = 0.4  # 停止して見せる時間(秒)
const FADE_TIME: float = 0.25  # フェードアウトにかける時間(秒)
const LIFETIME: float = RISE_TIME + HOLD_TIME + FADE_TIME  # 総表示時間(秒)
const FONT_SIZE: int = 20

var amount: int = 0
var is_invincible: bool = false

# class_name のグローバル登録に依存せず生成できるよう自身を preload する
const _SELF = preload("res://scripts/ui/DamageNumber.gd")


## 現在のシーンにダメージ数字を生成する。
## world_pos: 表示するワールド座標（通常は被弾した敵の位置）
## amount: 表示するダメージ量
## is_invincible: 無敵などでダメージが通らなかった場合 true（"MISS" 表示）
static func spawn(world_pos: Vector2, amount: int, is_invincible: bool = false) -> void:
  var tree := Engine.get_main_loop() as SceneTree
  if not tree or not tree.current_scene:
    return
  var dn := _SELF.new()
  dn.amount = amount
  dn.is_invincible = is_invincible
  tree.current_scene.add_child(dn)
  dn.global_position = world_pos


func _ready() -> void:
  z_index = 1000

  var label := Label.new()
  label.text = "MISS" if is_invincible else str(amount)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size", FONT_SIZE)
  label.add_theme_color_override("font_color", _text_color())
  label.add_theme_color_override("font_outline_color", Color.BLACK)
  label.add_theme_constant_override("outline_size", 4)
  # ワールド座標を中心にラベルを配置する
  label.custom_minimum_size = Vector2(80, 0)
  label.position = Vector2(-40, -20)
  add_child(label)

  var tween := create_tween()
  # 1) 少し上へ移動（生成位置からの相対移動。tween開始時の実際の位置が基準になる）
  (
    tween
    . tween_property(self, "position:y", -RISE_DISTANCE, RISE_TIME)
    . as_relative()
    . set_trans(Tween.TRANS_QUAD)
    . set_ease(Tween.EASE_OUT)
  )
  # 2) 短時間停止して見せる
  tween.tween_interval(HOLD_TIME)
  # 3) フェードアウトして削除
  tween.tween_property(self, "modulate:a", 0.0, FADE_TIME).set_ease(Tween.EASE_IN)
  tween.tween_callback(queue_free)


func _text_color() -> Color:
  if is_invincible:
    return Color(0.6, 0.6, 0.6)  # 無敵中はグレー
  if amount >= 50:
    return Color(1.0, 0.4, 0.2)  # 大ダメージはオレンジ
  return Color(1.0, 0.9, 0.3)  # 通常は黄色
