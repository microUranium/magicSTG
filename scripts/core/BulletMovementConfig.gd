# 弾丸の移動設定
class_name BulletMovementConfig extends Resource

enum MovementType { STRAIGHT, DECELERATE, ACCELERATE, SINE_WAVE, HOMING, GRAVITY }  # 直進  # 減速  # 加速  # サイン波軌道  # 追尾  # 重力

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
@export var bounce_factor: float = 0.0  # 0-1, 地面との衝突時の反発係数
@export var air_resistance: float = 0.0  # 0-1, 空気抵抗
