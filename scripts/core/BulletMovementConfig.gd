# 弾丸の移動設定
class_name BulletMovementConfig extends Resource

enum MovementType { STRAIGHT, DECELERATE, ACCELERATE, SINE_WAVE, HOMING }  # 直進  # 減速  # 加速  # サイン波軌道  # 追尾

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
@export var homing_turn_rate: float = 2.0
