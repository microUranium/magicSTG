extends Node

@export_file("*.tscn") var title_scene := "res://scenes/levels/title_screen.tscn"
@export_file("*.tscn") var stage_scene := "res://scenes/levels/stage_root.tscn"
@export_file("*.tscn") var equipment_scene := "res://scenes/levels/equipment_root.tscn"
@export_file("*.tscn") var result_inventory_scene := "res://scenes/levels/result_inventory.tscn"
@export_file("*.tscn") var stage_select_scene := "res://scenes/levels/stage_select.tscn"


#-------------------------------------------------
func change_to_title():
  get_tree().change_scene_to_file(title_scene)


func start_stage():
  get_tree().change_scene_to_file(stage_scene)


func start_equipment_screen():
  get_tree().change_scene_to_file(equipment_scene)


func start_result_inventory():
  get_tree().change_scene_to_file(result_inventory_scene)


func start_stage_select_screen():
  get_tree().change_scene_to_file(stage_select_scene)

#-------------------------------------------------
