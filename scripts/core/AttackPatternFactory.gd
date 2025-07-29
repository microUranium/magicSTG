# 攻撃パターンを簡単に作成するためのファクトリークラス
extends RefCounted
class_name AttackPatternFactory

# プリセット用の弾丸シーンパス（実際のプロジェクトに合わせて調整）
const DEFAULT_BULLET_SCENE = preload("res://scenes/bullets/universal_bullet.tscn")
const BARRIER_BULLET_SCENE = preload("res://scenes/bullets/enhanced_barrier_bullet.tscn")

# === 基本パターン作成メソッド ===


static func create_single_shot(
  bullet_scene: PackedScene = DEFAULT_BULLET_SCENE, damage: int = 5
) -> AttackPattern:
  """単発射撃パターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  pattern.bullet_scene = bullet_scene
  pattern.bullet_count = 1
  pattern.damage = damage
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  return pattern


static func create_rapid_fire(
  bullet_scene: PackedScene = DEFAULT_BULLET_SCENE,
  shots: int = 5,
  interval: float = 0.1,
  damage: int = 3
) -> AttackPattern:
  """連射パターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.RAPID_FIRE
  pattern.bullet_scene = bullet_scene
  pattern.bullet_count = 1
  pattern.rapid_fire_count = shots
  pattern.rapid_fire_interval = interval
  pattern.damage = damage
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  return pattern


static func create_single_circle_shot(
  bullet_scene: PackedScene = DEFAULT_BULLET_SCENE, bullet_count: int = 8, damage: int = 4
) -> AttackPattern:
  """円形単発射撃パターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  pattern.bullet_scene = bullet_scene
  pattern.bullet_count = bullet_count
  pattern.damage = damage
  pattern.direction_type = AttackPattern.DirectionType.CIRCLE
  pattern.base_direction = Vector2.DOWN
  return pattern


static func create_spread_shot(
  bullet_scene: PackedScene = DEFAULT_BULLET_SCENE,
  bullet_count: int = 5,
  spread_angle: float = 60.0,
  damage: int = 4
) -> AttackPattern:
  """扇状射撃パターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  pattern.bullet_scene = bullet_scene
  pattern.bullet_count = bullet_count
  pattern.angle_spread = spread_angle
  pattern.damage = damage
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  return pattern


static func create_barrier_bullets(
  bullet_scene: PackedScene = BARRIER_BULLET_SCENE,
  bullet_count: int = 8,
  radius: float = 100.0,
  rotation_duration: float = 3.0,
  damage: int = 5
) -> AttackPattern:
  """バリア弾パターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.BARRIER_BULLETS
  pattern.bullet_scene = bullet_scene
  pattern.bullet_count = bullet_count
  pattern.circle_radius = radius
  pattern.rotation_duration = rotation_duration
  pattern.damage = damage
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  return pattern


static func create_spiral_shot(
  bullet_scene: PackedScene = DEFAULT_BULLET_SCENE, bullet_count: int = 16, damage: int = 3
) -> AttackPattern:
  """螺旋射撃パターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.SPIRAL
  pattern.bullet_scene = bullet_scene
  pattern.bullet_count = bullet_count
  pattern.damage = damage
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  return pattern


# === 複合パターン作成メソッド ===


static func create_layered_pattern(
  base_patterns: Array[AttackPattern], delays: Array[float] = []
) -> AttackPattern:
  """複数パターンを組み合わせた複合パターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT  # ダミー
  pattern.pattern_layers = base_patterns
  pattern.layer_delays = delays

  # 最初のパターンから基本設定を継承
  if base_patterns.size() > 0:
    var first_pattern = base_patterns[0]
    pattern.bullet_scene = first_pattern.bullet_scene
    pattern.target_group = first_pattern.target_group

  return pattern


static func create_alternating_pattern(
  pattern_a: AttackPattern, pattern_b: AttackPattern, switch_delay: float = 1.0
) -> AttackPattern:
  """2つのパターンを交互に実行する複合パターンを作成"""
  return create_layered_pattern([pattern_a, pattern_b], [0.0, switch_delay])


static func create_circle_shot_spread() -> AttackPattern:
  """円形配置＋連射の複合パターン"""
  var circle_pattern = create_single_circle_shot(DEFAULT_BULLET_SCENE, 8, 4)
  var rapid_pattern = create_rapid_fire(DEFAULT_BULLET_SCENE, 3, 0.1, 3)
  return create_layered_pattern([circle_pattern, rapid_pattern], [0.0, 0.5])


# === カスタムパラメータ付きパターン ===


static func create_custom_pattern(script: GDScript, parameters: Dictionary = {}) -> AttackPattern:
  """カスタムスクリプトを使用するパターンを作成"""
  var pattern = AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.CUSTOM
  pattern.custom_script = script
  pattern.custom_parameters = parameters
  return pattern


# === 設定チェーンメソッド（メソッドチェーン用） ===


static func with_target_group(pattern: AttackPattern, group: String) -> AttackPattern:
  """ターゲットグループを設定"""
  pattern.target_group = group
  return pattern


static func with_damage(pattern: AttackPattern, damage: int) -> AttackPattern:
  """ダメージを設定"""
  pattern.damage = damage
  return pattern


static func with_speed(pattern: AttackPattern, speed: float) -> AttackPattern:
  """弾速を設定"""
  pattern.bullet_speed = speed
  return pattern


static func with_direction_type(
  pattern: AttackPattern, dir_type: AttackPattern.DirectionType
) -> AttackPattern:
  """方向タイプを設定"""
  pattern.direction_type = dir_type
  return pattern


static func with_angle_offset(pattern: AttackPattern, offset: float) -> AttackPattern:
  """角度オフセットを設定"""
  pattern.angle_offset = offset
  return pattern
