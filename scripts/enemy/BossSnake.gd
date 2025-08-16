extends WormBoss
class_name BossSnake

signal change_body_attack(_phase_idx: int)  # ボディアタックの変更を通知

# 衝突ダメージ設定
@export var damage: int = 10  # プレイヤーに与えるダメージ

# HP段階的破壊システム
var destruction_thresholds: Array[float] = []  # 節破壊のHPしきい値
var segments_destroyed: int = 0  # 破壊済み節数


func _ready():
  super._ready()
  StageSignals.emit_request_change_background_scroll_speed(0, 2.5)


func setup():
  """初期化処理"""
  super.setup()

  # HP段階破壊しきい値を計算
  _calculate_destruction_thresholds()


func _on_area_entered(body):
  if body.is_in_group("players"):
    body.take_damage(damage)


func on_hp_changed(current_hp: int, max_hp: int) -> void:
  """HP変更時の処理"""
  if current_hp <= max_hp * 0.3 and ai._phase_idx == 2:
    # Phase 2でHPが30%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    ai._phase_idx += 1
    change_body_attack.emit(ai._phase_idx)
  elif current_hp <= max_hp * 0.2 and ai._phase_idx == 3:
    # Phase 3でHPが20%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    ai._phase_idx += 1
    change_body_attack.emit(ai._phase_idx)
  elif current_hp <= max_hp * 0.1 and ai._phase_idx == 4:
    # Phase 4でHPが10%以下になったら次のフェーズへ
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    ai._phase_idx += 1
    change_body_attack.emit(ai._phase_idx)
  elif current_hp <= 0:
    StageSignals.emit_request_hud_flash(1)  # フラッシュを発行
    StageSignals.emit_request_change_background_scroll_speed(0, 2.5)  # スクロール速度を0に
    StageSignals.emit_request_start_vibration()  # Start vibration
    StageSignals.emit_destroy_bullet()  # Destroy bullet
    StageSignals.emit_bgm_stop_requested(1.0)  # BGM停止リクエスト
    StageSignals.emit_signal("sfx_play_requested", "destroy_boss", global_position, 0, 0)
    _spawn_destroy_particles()
    queue_free()

  # HP比率による段階的節破壊
  _check_segment_destruction(current_hp, max_hp)


func take_damage(amount: int) -> void:
  if ai._phase_idx <= 1:
    return
  super.take_damage(amount)


func _calculate_destruction_thresholds():
  """HP段階破壊のしきい値を計算"""
  if not hp_node or not segment_manager:
    return

  var max_hp = hp_node.max_hp
  var total_segments = segment_count

  destruction_thresholds.clear()

  var destruction_range = 1.0
  var step = destruction_range / total_segments

  for i in range(total_segments):
    var threshold_ratio = 1.0 - (step * (i + 1))
    destruction_thresholds.append(threshold_ratio)


func _check_segment_destruction(current_hp: int, max_hp: int):
  """HP比率に基づく段階的節破壊チェック"""
  if not segment_manager or destruction_thresholds.is_empty():
    return

  var hp_ratio = float(current_hp) / float(max_hp)

  # HP30%以下は節を破壊しない
  if hp_ratio <= 0.3:
    return

  # 現在のHPで破壊すべき節数を計算
  var should_destroy = 0
  for threshold in destruction_thresholds:
    if hp_ratio <= threshold:
      should_destroy += 1
    else:
      break

  # 破壊が必要な場合
  while segments_destroyed < should_destroy and segment_manager.get_segment_count() > 0:
    _destroy_segment()
    segments_destroyed += 1


func _destroy_segment():
  """末尾の節を破壊（エフェクト付き）"""
  if not segment_manager:
    return

  var segments = segment_manager.get_all_segments()
  if segments.is_empty():
    return

  var last_segment = segments[-1]
  if last_segment and is_instance_valid(last_segment):
    # 破壊エフェクト
    var sprite = last_segment.get_node("AnimatedSprite2D")
    if sprite:
      FlashUtility.flash_white(sprite)

    # パーティクル効果（可能であれば）
    (
      last_segment._spawn_destroy_particles()
      if last_segment.has_method("_spawn_destroy_particles")
      else null
    )

    # 効果音
    StageSignals.emit_signal(
      "sfx_play_requested", "destroy_enemy", last_segment.global_position, 0, 0
    )

  # 実際に削除
  segment_manager.remove_last_segment()
