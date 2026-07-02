@tool
extends Resource
class_name PhaseResource

@export var patterns: Array[EnemyPatternResource] = []
@export var loop_type: int = 0  # 0=SEQ, 1=RANDOM   ← 各 Phase 個別で可

# --- HPバー表示制御 ---
@export var show_hp_bar: bool = false  # このフェーズでHPバーを表示するか（登場/会話は false）
@export var end_hp_ratio: float = 0.0  # PER_PHASE時の区間下端 HP 割合（max_hp 基準, 0.0〜1.0）
@export var bar_merge_with_previous: bool = false  # PER_PHASE時、リセットせず前フェーズの区間を継続
