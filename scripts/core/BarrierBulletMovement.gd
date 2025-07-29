# 設定データクラス
class_name BarrierBulletMovement extends Resource

enum Phase { MOVING_TO_ORBIT, ORBITING, PROJECTILE }  # 軌道への移動中  # 軌道回転中  # 直進中

enum ProjectileDirection { TO_TARGET, CURRENT_VELOCITY, FIXED, RANDOM }  # ターゲットに向かう  # 現在の速度方向を維持  # 固定方向  # ランダム方向

# === 軌道設定 ===
@export var orbit_radius: float = 100.0
@export var approach_duration: float = 0.5  # 軌道到達時間
@export var orbit_duration: float = 3.0  # 軌道回転時間
@export var rotation_speed: float = 90.0  # 回転速度（度/秒）

# === 直進設定 ===
@export var projectile_direction_type: ProjectileDirection = ProjectileDirection.TO_TARGET
@export var fixed_direction: Vector2 = Vector2.DOWN
@export var projectile_speed: float = 200.0
