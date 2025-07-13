extends ItemBase
class_name AttackCoreItem

@export var projectile_scene: PackedScene  # 発射するプロジェクタイルのシーン
@export var damage_base: float = 1.0  # 基本ダメージ
@export var cooldown_sec_base: float = 0.2  # 基本クールダウン時間
@export var base_modifiers: Dictionary = {}  # 攻撃核の基本的なパラメータ


func _init() -> void:
  item_type = ItemType.ATTACK_CORE
