# 攻撃警告の設定リソース
class_name AttackWarningConfig extends Resource

# === 基本視覚設定 ===
@export var base_color: Color = "#801919"  # 基本色（赤系）
@export var glow_width: float = 8.0  # ぼんやり部分の幅
@export var outline_width: float = 2.0  # 輪郭線の幅
@export var warning_duration: float = 1.0  # 警告表示時間（フェードイン時間と同一）
@export var glow_intensity: float = 2.0  # グロー強度
@export var warning_length: float = 500.0  # 警告線の長さ
