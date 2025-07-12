extends Node

@export_file("*.tscn") var title_scene := "res://assets/title/title_screen.tscn"
@export_file("*.tscn") var stage_scene := "res://assets/main/main.tscn"

func _ready():
  change_to_title()

#-------------------------------------------------
func change_to_title():
  get_tree().change_scene_to_file(title_scene)

func start_stage():
  get_tree().change_scene_to_file(stage_scene)

#-------------------------------------------------
