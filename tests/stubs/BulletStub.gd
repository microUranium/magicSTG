extends Node2D
class_name BulletStub

var initialized := false
var damage := 0.0
var speed := 0.0
var pierce := 0
var direction: Vector2 = Vector2.UP
var target_group: String = "enemies"


func setup(dmg: float, spd: float, pc: int) -> void:
  damage = dmg
  speed = spd
  pierce = pc
  initialized = true


func apply_visual_config(config):
  pass


func apply_movement_config(config):
  pass


func apply_barrier_movement_config(config):
  pass
