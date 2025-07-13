extends Resource
class_name WaveData

#------------------------------
# Wave 内の出現イベント
# Inspector でドラッグ＆ドロップして順序変更可
#------------------------------
@export var spawn_events: Array[SpawnEvent] = []


#------------------------------
# 便利ヘルパ（任意） : 合計敵数を返す
#------------------------------
func get_total_enemies() -> int:
  var total := 0
  for ev in spawn_events:
    total += ev.count
  return total
