# 弾丸の移動設定
class_name BulletMovementConfig extends Resource

enum MovementType {STRAIGHT, DECELERATE, ACCELERATE, SINE_WAVE, HOMING, GRAVITY, SPIRAL, BOOMERANG}  # 直進  # 減速  # 加速  # サイン波軌道  # 追尾  # 重力  # 螺旋  # ブーメラン（減速→停止→プレイヤーへ帰還）

enum RotationMode { MOVEMENT_DIRECTION, SELF_ROTATION, FIXED }  # 移動方向に合わせる  # 設定された角速度で自転する  # 回転しない（初期角度を保持）

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
## true なら弾の初期進行方向のY符号から重力方向を決める（上に撃てば重力も上向き）。
## 後方発射で攻撃方向が反転しても弾が片側に溜まらないようにするための設定。
## 既定 false で従来どおり gravity_direction をそのまま使う。
@export var gravity_follows_direction: bool = false
@export var air_resistance: float = 0.0  # 0-1, 空気抵抗

# ブーメラン設定
@export_group("Boomerang Settings")
@export var boomerang_outbound_time: float = 1.5  # 減速して停止するまでの秒数。往路距離 = initial_speed * time / 2
@export var boomerang_return_accel: float = 900.0  # 帰還時の加速度（ピクセル/秒²）
@export var boomerang_return_max_speed: float = 700.0  # 帰還時の最大速度。プレイヤー移動速度を上回る値にする
@export var boomerang_catch_radius: float = 24.0  # この距離までプレイヤーに近づいたら回収する
@export_group("")

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
@export var spiral_initial_radius: float = 0.0  # 初期半径（ピクセル）

# 回転設定
@export_group("Rotation Settings")
@export var rotation_mode: RotationMode = RotationMode.MOVEMENT_DIRECTION  # 回転モード
@export_range(0.0, 360.0, 0.1, "radians_as_degrees") var initial_rotation: float = 0.0  # 初期角度（度）、FIXED/SELF_ROTATIONモードで使用
@export var angular_velocity: float = 0.0  # 角速度（度/秒）、負の値で逆回転
