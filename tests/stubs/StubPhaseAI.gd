# BossHpBar テスト用のフェーズAIスタブ。
# 実ボスAI（EnemyPatternedAIBase 派生）が持つ phase_changed / phases / _phase_idx を模す。
# preload 専用のため class_name は付けない。
extends Node

@warning_ignore("unused_signal")
signal phase_changed(phase_idx: int)

var phases: Array = []
var _phase_idx: int = 0
