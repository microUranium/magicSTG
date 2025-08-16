extends ItemBase
class_name AttackCoreItem

enum PatternType { SINGLE_SHOT, BEAM, CUSTOM }

@export var pattern_type: PatternType = PatternType.SINGLE_SHOT  # パターンタイプ
@export var core_scene: PackedScene
@export var projectile_scene: PackedScene  # 発射するプロジェクタイルのシーン
@export var damage_base: float = 1.0  # 基本ダメージ
@export var cooldown_sec_base: float = 0.2  # 基本クールダウン時間
@export var base_modifiers: Dictionary = {}  # 攻撃核の基本的なパラメータ

@export var attack_pattern: AttackPattern = null  # 攻撃パターン


func _init() -> void:
  item_type = ItemType.ATTACK_CORE
