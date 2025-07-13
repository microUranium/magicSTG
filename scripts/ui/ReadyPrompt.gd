extends CanvasLayer
class_name ReadyPrompt

@export_range(0.1, 10.0, 0.1, "suffix:s")
var show_time: float = 1.5      # 表示秒数

signal finished                 # 表示が終わったら emit

func _ready():
  # フェードイン / フェードアウトを簡易実装
  $ReadyLabel.modulate.a = 0.0
  var tween := create_tween()
  tween.tween_property($ReadyLabel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
  tween.tween_interval(show_time - 0.6)
  tween.tween_property($ReadyLabel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
  tween.finished.connect(_on_tween_finished)
  
func _on_tween_finished():
  emit_signal("finished")
