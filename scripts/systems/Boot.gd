extends Node


func _ready():
  GameFlow.change_to_title(false)  # 起動直後は暗転させる前の画面が無いのでフェードしない
