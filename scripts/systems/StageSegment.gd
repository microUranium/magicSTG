@tool
extends Resource
class_name StageSegment

enum Kind { WAVE, DIALOGUE }

@export_enum("WAVE", "DIALOGUE") var kind: int = Kind.WAVE

@export var wave_data: WaveData = null  # kind == WAVE 用
@export var dialogue_data: DialogueData = null  # kind == DIALOGUE 用
