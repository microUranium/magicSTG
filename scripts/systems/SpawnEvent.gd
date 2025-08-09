extends Resource
class_name SpawnEvent

#------------------------------
# 出現パターン
#------------------------------
enum Pattern { SINGLE_RANDOM, BURST_SAME_POS, LINE_HORIZ, FROM_TOP_SPACING }  # 1 体をランダム位置  # N 体を同座標・等間隔  # 左→右に横一列（追加例）

@export_enum("SINGLE_RANDOM", "BURST_SAME_POS", "LINE_HORIZ", "FROM_TOP_SPACING")
var pattern: int = Pattern.SINGLE_RANDOM

#------------------------------
# 出現させる敵シーン群
#------------------------------
@export var enemy_scenes: Array[PackedScene] = []

#------------------------------
# 個体数・間隔
#------------------------------
@export_range(1, 99, 1) var count: int = 5

@export_range(0, 10.0, 0, "suffix:s") var interval: float = 0.4

#------------------------------
# 基準座標（BURST 等で使用）
#------------------------------
@export var base_pos: Vector2 = Vector2.ZERO

@export var parameters: Dictionary = {}  # 敵に渡すパラメータ
