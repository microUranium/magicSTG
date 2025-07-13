@tool
extends Resource
class_name PhaseResource

@export var patterns: Array[EnemyPatternResource] = []
@export var loop_type: int = 0  # 0=SEQ, 1=RANDOM   ← 各 Phase 個別で可
