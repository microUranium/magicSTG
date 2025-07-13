extends Resource
class_name DialogueData

@export var lines: Array[DialogueLine] = []  # Inspector で順序変更可


# 便利メソッド（任意） : 総行数
func get_line_count() -> int:
  return lines.size()
