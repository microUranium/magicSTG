@tool
extends Resource
class_name PhaseResource

@export var patterns: Array[EnemyPatternResource] = []
@export var loop_type: int = 0  # 0=SEQ, 1=RANDOM   ← 各 Phase 個別で可
@export var consumes_hp: bool = true  # false = 会話/導入フェーズ（HPバー非表示・無敵想定）
@export var end_hp_ratio: float = 0.0  # このフェーズが終了する HP 割合（max_hp 基準, 0.0〜1.0）
