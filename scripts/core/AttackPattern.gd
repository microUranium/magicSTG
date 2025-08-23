# 攻撃パターンを定義するリソースクラス
extends Resource
class_name AttackPattern

enum PatternType { SINGLE_SHOT, RAPID_FIRE, BARRIER_BULLETS, SPIRAL, BEAM, CUSTOM }  # 単発  # 連射  # 円形配置  # バリア弾（回転→直進）  # 螺旋  # ビーム  # カスタムスクリプト用

enum DirectionType { FIXED, TO_PLAYER, RANDOM, CIRCLE, CUSTOM }  # 固定方向  # プレイヤー狙い  # ランダム # 円形  # カスタム計算

enum MovementType { STRAIGHT, CURVE, ORBIT_THEN_STRAIGHT, HOMING }  # 直進  # カーブ  # 軌道→直進  # 追尾

# === 基本設定 ===
@export var pattern_type: PatternType = PatternType.SINGLE_SHOT
@export var bullet_scene: PackedScene
@export var target_group: String = "players"
@export var damage: int = 5
@export var bullet_range: float = 0.0  # 弾丸の射程距離 0なら無限
@export var bullet_lifetime: float = 0.0  # 弾丸の有効時間 0なら無限
@export var auto_start: bool = true  # AttackCoreの自動発射設定

# === 弾丸外観、動作設定 ===
@export var bullet_visual_config: BulletVisualConfig  # 弾丸の外観設定
@export var bullet_movement_config: BulletMovementConfig  # 弾丸の動作設定
@export var barrier_movement_config: BarrierBulletMovement  # バリア弾の動作設定

# === 発射設定 ===
@export var bullet_count: int = 1
@export var rapid_fire_count: int = 1
@export var rapid_fire_interval: float = 0.1
@export var burst_delay: float = 0.5  # 複数バースト間の間隔

# === 方向設定 ===
@export var direction_type: DirectionType = DirectionType.TO_PLAYER
@export var base_direction: Vector2 = Vector2.DOWN
@export var angle_spread: float = 0.0  # 扇状に広がる角度（度）
@export var angle_offset: float = 0.0  # 基準角度からのオフセット

# === 円形配置設定 ===
@export var circle_radius: float = 100.0
@export var rotation_speed: float = 90.0  # 度/秒
@export var rotation_duration: float = 3.0

# === 軌道設定 ===
@export var movement_type: MovementType = MovementType.STRAIGHT
@export var bullet_speed: float = 200.0
@export var curve_strength: float = 0.0
@export var orbit_radius: float = 50.0

# === ビーム設定 ===
@export var beam_duration: float = 1.0
@export var beam_scene: PackedScene
@export var continuous_damage: bool = false  # ビームが持続的にダメージを与えるかどうか
@export var beam_visual_config: BeamVisualConfig  # ビーム外観設定
@export var beam_direction_override: Vector2 = Vector2.ZERO  # ビーム方向の上書き（ZERO時は direction_type を使用）

# === カスタム設定 ===
@export var custom_script: GDScript  # カスタム動作用
@export var custom_parameters: Dictionary = {}  # カスタムパラメータ

# === 複合パターン設定 ===
@export var pattern_layers: Array[AttackPattern] = []  # 複数パターンの組み合わせ
@export var layer_delays: Array[float] = []  # 各レイヤーの発動遅延

# === 警告設定 ===
@export var warning_config: AttackWarningConfig  # 警告設定（nullの場合は警告なし）


# パターンの基本方向を計算
func calculate_base_direction(from_pos: Vector2, target_pos: Vector2) -> Vector2:
  match direction_type:
    DirectionType.FIXED:
      return base_direction.normalized()

      # カスタムスクリプトで計算
    DirectionType.TO_PLAYER:
      return (target_pos - from_pos).normalized()

      # カスタムスクリプトで計算
    DirectionType.RANDOM:
      return base_direction.normalized()

      # カスタムスクリプトで計算
    DirectionType.CUSTOM:
      # カスタムスクリプトで計算
      if custom_script and custom_script.has_method("calculate_direction"):
        return custom_script.calculate_direction(from_pos, target_pos, custom_parameters)
      return base_direction.normalized()
    _:
      return base_direction.normalized()


# 円形配置での個別弾の方向を計算
func calculate_circle_direction(index: int, total_count: int, base_dir: Vector2) -> Vector2:
  var angle_step = TAU / max(total_count, 1)
  var angle = angle_step * index + deg_to_rad(angle_offset)
  return base_dir.rotated(angle)


# 扇状配置での個別弾の方向を計算
func calculate_spread_direction(index: int, total_count: int, base_dir: Vector2) -> Vector2:
  if total_count <= 1:
    return base_dir
  var spread_rad = deg_to_rad(angle_spread)
  var step = spread_rad / (total_count - 1)
  var angle = -spread_rad * 0.5 + step * index + deg_to_rad(angle_offset)
  return base_dir.rotated(angle)


# 不等間隔扇状配置での個別弾の方向を計算（RANDOMタイプ用）
func calculate_random_spread_direction(base_dir: Vector2) -> Vector2:
  # angle_spreadが設定されていない場合は通常のランダム
  if angle_spread <= 0.0:
    return Vector2.from_angle(randf() * TAU)

  # 扇状範囲内でランダムな角度を生成
  var spread_rad = deg_to_rad(angle_spread)
  var random_angle = randf_range(-spread_rad * 0.5, spread_rad * 0.5)
  var total_angle = random_angle + deg_to_rad(angle_offset)

  return base_dir.rotated(total_angle)


# パターンが複合型かどうか
func is_composite_pattern() -> bool:
  return pattern_layers.size() > 0
