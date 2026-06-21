extends ActiveBlessingBase

## 打消の加護：発動時点で場に存在する敵弾をすべて消す（アクティブ型）。
## スロット番号キー(1/2/3)で発動。1ステージあたりの使用回数とクールダウンは基底クラスが管理。
## エンチャント「強奪」(nullify_steal_chance_pct) 装着時は、敵撃破ごとに確率で使用回数が回復する（上限超過なし）。

var _steal_chance: float = 0.0  # 強奪：敵撃破時に使用回数が増える確率（未装着なら0）


func _recalc_stats() -> void:
  super._recalc_stats()
  _steal_chance = _sum_pct("nullify_steal_chance_pct")


func on_equip(player) -> void:
  super.on_equip(player)
  if _steal_chance > 0.0 and not StageSignals.enemy_defeated.is_connected(_on_enemy_defeated):
    StageSignals.enemy_defeated.connect(_on_enemy_defeated)


func _on_unequip_impl(_player) -> void:
  if StageSignals.enemy_defeated.is_connected(_on_enemy_defeated):
    StageSignals.enemy_defeated.disconnect(_on_enemy_defeated)


func _on_enemy_defeated(_enemy) -> void:
  if _paused or _uses_remaining >= max_uses:  # 上限は超えない
    return
  if randf() < _steal_chance:
    _uses_remaining += 1
    set_gauge(float(_uses_remaining))


func _do_activate() -> bool:
  # 敵弾（プレイヤーを狙う弾 = target_group "players"）のみ消去
  StageSignals.emit_destroy_bullets_by_target("players")
  StageSignals.emit_request_hud_flash(0.3)  # 発動時に画面フラッシュ
  StageSignals.sfx_play_requested.emit("break_shield", TargetService.get_player_position(), 0, 1.0)
  return true
