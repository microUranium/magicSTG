# 弾丸の移動設定
class_name BulletMovementConfig extends Resource

enum MovementType { STRAIGHT, DECELERATE, ACCELERATE, SINE_WAVE, HOMING, GRAVITY, SPIRAL }  # 直進  # 減速  # 加速  # サイン波軌道  # 追尾  # 重力  # 螺旋

@export var movement_type: MovementType = MovementType.STRAIGHT
@export var initial_speed: float = 200.0

# 減速設定
@export var deceleration_rate: float = 100.0
@export var min_speed: float = 50.0

# 加速設定
@export var acceleration_rate: float = 50.0
@export var max_speed: float = 500.0

# サイン波設定
@export var wave_amplitude: float = 50.0
@export var wave_frequency: float = 2.0

# 追尾設定
@export var homing_duration: float = 3.0  # 追尾時間（秒）、0なら永続的
@export var max_turn_angle_per_second: float = 180.0  # 1秒あたりの最大回転角度（度）

# 重力設定
@export var gravity_strength: float = 980.0  # ピクセル/秒²
@export var gravity_direction: Vector2 = Vector2.DOWN
@export var air_resistance: float = 0.0  # 0-1, 空気抵抗

# 反射設定（全ての移動タイプで使用可能）
@export var bounce_factor: float = 0.0  # 0-1, 境界との衝突時の反発係数
@export var max_bounces: int = 0  # 最大反射回数、0なら無制限

# 螺旋設定
@export_group("Spiral Settings")
@export var spiral_radius_growth: float = 50.0  # 1秒あたりの半径増加量（ピクセル/秒）、負の値で内向き螺旋
@export var spiral_rotation_speed: float = 360.0  # 回転速度（度/秒）
@export var spiral_clockwise: bool = true  # true=時計回り, false=反時計回り
@export_range(0.0, 360.0, 0.1, "radians_as_degrees") var spiral_phase_offset: float = 0.0  # 開始角度オフセット（度）
@export var spiral_acceleration: float = 0.0  # 加速度（ピクセル/秒²）、0なら等速
@export var spiral_max_speed: float = 500.0  # 最大速度（加速時の制限）
@export var spiral_min_speed: float = 10.0  # 最小速度（減速時の制限）
