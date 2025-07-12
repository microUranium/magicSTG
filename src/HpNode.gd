extends Node

signal hp_changed(current_hp, max_hp)

@export var max_hp: int = 10
var current_hp: int

func _ready():
    current_hp = max_hp
    emit_signal("hp_changed", current_hp, max_hp)

func take_damage(amount: int = 1):
    current_hp -= amount
    if current_hp < 0:
        current_hp = 0
    emit_signal("hp_changed", current_hp, max_hp)

func heal(amount: int = 1):
    current_hp += amount
    if current_hp > max_hp:
        current_hp = max_hp
    emit_signal("hp_changed", current_hp, max_hp)

func set_max_hp(value: int):
    max_hp = value
    current_hp = min(current_hp, max_hp)
    emit_signal("hp_changed", current_hp, max_hp)