# 汎用攻撃コア - 設定リソースベースで任意の攻撃パターンを実行
extends AttackCoreBase
class_name UniversalAttackCore

@export var override_target_group: String = ""  # パターンの設定を上書き
@export var show_debug_info: bool = false

@onready var debug_display: Node2D = $DebugDisplay
@onready var debug_label: Label = $DebugDisplay/Label
@onready var debug_line: Line2D = $DebugDisplay/Line2D

var _pattern_executors: Dictionary = {}
var _current_execution: ExecutionContext = null


class ExecutionContext:
  var pattern: AttackPattern
  var start_time: float
  var bullets_spawned: int = 0
  var execution_id: int

  func _init(p: AttackPattern):
    pattern = p
    start_time = Time.get_time_dict_from_system()["second"]
    execution_id = randi()


func _ready() -> void:
  show_on_hud = false
  super._ready()
  if debug_display:
    debug_display.visible = show_debug_info and OS.is_debug_build()
  _register_pattern_executors()


func _register_pattern_executors() -> void:
  """パターン実行器を登録"""
  _pattern_executors[AttackPattern.PatternType.SINGLE_SHOT] = _execute_single_shot
  _pattern_executors[AttackPattern.PatternType.RAPID_FIRE] = _execute_rapid_fire
  _pattern_executors[AttackPattern.PatternType.BARRIER_BULLETS] = _execute_barrier_bullets
  _pattern_executors[AttackPattern.PatternType.SPIRAL] = _execute_spiral
  _pattern_executors[AttackPattern.PatternType.CUSTOM] = _execute_custom


func _do_fire() -> bool:
  """実際の発射処理"""
  if not attack_pattern:
    push_warning("UniversalAttackCore: AttackPattern is not set.")
    return false

  if not _validate_firing_conditions():
    return false

  # デバッグ情報更新
  if show_debug_info and OS.is_debug_build():
    _update_debug_display()

  # 実行コンテキストを作成
  _current_execution = ExecutionContext.new(attack_pattern)

  # パターンに応じて実行
  var success = false
  if attack_pattern.is_composite_pattern():
    success = await _execute_composite_pattern()
  else:
    success = await _execute_single_pattern(attack_pattern)

  _current_execution = null
  return success


func _validate_firing_conditions() -> bool:
  """発射条件の検証"""
  if not _owner_actor:
    push_warning("UniversalAttackCore: Owner actor is not set.")
    return false

  if not attack_pattern.bullet_scene:
    push_warning("UniversalAttackCore: Attack pattern has no bullet scene.")
    return false

  return true


#---------------------------------------------------------------------
# Pattern Execution (パターン実行)
#---------------------------------------------------------------------
func _execute_composite_pattern() -> bool:
  """複合パターンを実行"""
  var success = true

  for i in range(attack_pattern.pattern_layers.size()):
    var layer_pattern = attack_pattern.pattern_layers[i]
    var delay = attack_pattern.layer_delays[i] if i < attack_pattern.layer_delays.size() else 0.0

    if delay > 0:
      await get_tree().create_timer(delay).timeout

    if not await _execute_single_pattern(layer_pattern):
      success = false

  return success


func _execute_single_pattern(pattern: AttackPattern) -> bool:
  """単一パターンを実行"""
  var executor = _pattern_executors.get(pattern.pattern_type)
  if not executor:
    push_warning("UniversalAttackCore: Unknown pattern type: %s" % pattern.pattern_type)
    return false

  return await executor.call(pattern)


# === パターン実行器群 ===


func _execute_single_shot(pattern: AttackPattern) -> bool:
  """単発射撃"""
  var target_pos = _get_player_position()
  var base_dir = pattern.calculate_base_direction(_owner_actor.global_position, target_pos)

  var success = true
  for i in range(pattern.bullet_count):
    var bullet_dir
    if pattern.direction_type == AttackPattern.DirectionType.CIRCLE:
      # 円形配置の場合、方向を計算
      bullet_dir = pattern.calculate_circle_direction(i, pattern.bullet_count, base_dir)
    else:
      # 通常の方向計算
      bullet_dir = pattern.calculate_spread_direction(i, pattern.bullet_count, base_dir)
    if not _spawn_bullet(pattern, bullet_dir, _owner_actor.global_position):
      success = false

    await get_tree().process_frame

  return success


func _execute_rapid_fire(pattern: AttackPattern) -> bool:
  """連射"""
  var success = true

  for burst in range(pattern.rapid_fire_count):
    if not await _execute_single_shot(pattern):
      success = false

    if burst < pattern.rapid_fire_count - 1:
      await get_tree().create_timer(pattern.rapid_fire_interval).timeout

  return success


func _execute_barrier_bullets(pattern: AttackPattern) -> bool:
  """バリア弾（回転→直進）"""
  var bullet_group = "barrier_bullets_" + str(ResourceUID.create_id())
  var target_pos = _get_player_position()

  var success = true
  for i in range(pattern.bullet_count):
    var bullet = _create_barrier_bullet(pattern, i, bullet_group, target_pos)
    if bullet:
      _start_barrier_bullet(bullet, pattern)
    else:
      success = false

    if pattern.rapid_fire_interval > 0:
      await get_tree().create_timer(pattern.rapid_fire_interval).timeout

  return success


func _execute_spiral(pattern: AttackPattern) -> bool:
  """螺旋射撃"""
  var target_pos = _get_player_position()
  var base_dir = pattern.calculate_base_direction(_owner_actor.global_position, target_pos)

  var success = true
  for i in range(pattern.bullet_count):
    # 螺旋の角度計算
    var spiral_angle = (TAU / pattern.bullet_count) * i
    var bullet_dir = base_dir.rotated(spiral_angle)

    if not _spawn_bullet(pattern, bullet_dir, _owner_actor.global_position):
      success = false

    # 螺旋の時間差
    await get_tree().create_timer(0.05).timeout

  return success


func _execute_custom(pattern: AttackPattern) -> bool:
  """カスタムパターン"""
  if pattern.custom_script and pattern.custom_script.has_method("execute_pattern"):
    return await pattern.custom_script.execute_pattern(self, pattern, _owner_actor)
  else:
    push_warning("UniversalAttackCore: Custom pattern has no execute_pattern method.")
    await get_tree().process_frame
    return false


# === ヘルパーメソッド ===


func _spawn_bullet(pattern: AttackPattern, direction: Vector2, spawn_pos: Vector2) -> bool:
  """基本的な弾丸を生成"""
  if not pattern.bullet_scene:
    return false

  if not can_fire():
    return false

  var parent = _find_bullet_parent()
  if not parent:
    push_warning("UniversalAttackCore: No valid parent node found.")
    return false

  var bullet = pattern.bullet_scene.instantiate()
  parent.add_child(bullet)

  # 弾丸の基本設定
  bullet.global_position = spawn_pos
  bullet.direction = direction
  bullet.speed = pattern.bullet_speed
  bullet.damage = pattern.damage

  # ターゲットグループ設定
  var target_group = (
    override_target_group if not override_target_group.is_empty() else pattern.target_group
  )
  bullet.target_group = target_group

  # 視覚・動作設定の適用
  _apply_bullet_configs(bullet, pattern)

  # 実行コンテキスト更新
  if _current_execution:
    _current_execution.bullets_spawned += 1

  return true


func _create_barrier_bullet(
  pattern: AttackPattern, index: int, group_id: String, target_pos: Vector2
):
  """バリア弾専用の弾丸を生成"""
  if not pattern.bullet_scene:
    return null

  if not can_fire():
    return false

  var parent = _find_bullet_parent()
  if not parent:
    return null

  var bullet = pattern.bullet_scene.instantiate()
  parent.add_child(bullet)

  # 視覚・動作設定の適用
  _apply_bullet_configs(bullet, pattern)

  # バリア弾特有の設定
  if bullet.has_method("setup_barrier_bullet"):
    bullet.setup_barrier_bullet(
      _owner_actor,
      group_id,
      pattern.bullet_count,
      index,
      _get_player_node(),
      pattern.circle_radius,
      pattern.damage,
      pattern.target_group
    )

  return bullet


func _start_barrier_bullet(bullet, pattern: AttackPattern):
  """バリア弾の開始処理"""
  if bullet.has_method("start_rotation"):
    bullet.start_rotation(pattern.rotation_duration, pattern.rotation_speed)


func _apply_bullet_configs(bullet: Node, pattern: AttackPattern):
  """弾丸に視覚・動作設定を適用"""
  # 視覚設定の適用
  if pattern.bullet_visual_config and bullet.has_method("apply_visual_config"):
    bullet.apply_visual_config(pattern.bullet_visual_config)

  # 動作設定の適用
  if pattern.bullet_movement_config and bullet.has_method("apply_movement_config"):
    bullet.apply_movement_config(pattern.bullet_movement_config)

  # バリア弾の動作設定
  if pattern.barrier_movement_config and bullet.has_method("apply_barrier_movement_config"):
    bullet.apply_barrier_movement_config(pattern.barrier_movement_config)


func _get_player_position() -> Vector2:
  var player = _get_player_node()
  return player.global_position if player else Vector2.ZERO


func _get_player_node() -> Node2D:
  return get_tree().current_scene.get_node_or_null("Player")


#---------------------------------------------------------------------
# Debug System (デバッグシステム)
#---------------------------------------------------------------------
func _update_debug_display():
  """デバッグ情報の更新"""
  if not attack_pattern:
    return

  _update_debug_label()
  _update_debug_line()


func _update_debug_label():
  """デバッグラベルの更新"""
  if not debug_label:
    return

  var pattern_name = attack_pattern.resource_path.get_file().get_basename()
  var execution_info = ""
  if _current_execution:
    execution_info = "\nBullets: %d" % _current_execution.bullets_spawned

  debug_label.text = (
    "Pattern: %s\nCount: %d\nDamage: %d%s"
    % [pattern_name, attack_pattern.bullet_count, attack_pattern.damage, execution_info]
  )


func _update_debug_line():
  """デバッグライン（射撃方向）の更新"""
  if not debug_line or not _owner_actor:
    return

  var player_pos = _get_player_position()
  var direction = attack_pattern.calculate_base_direction(_owner_actor.global_position, player_pos)
  var line_end = direction * 100.0  # 100ピクセルの線

  debug_line.clear_points()
  debug_line.add_point(Vector2.ZERO)
  debug_line.add_point(line_end)
  debug_line.default_color = Color.RED


#---------------------------------------------------------------------
# AttackCoreBase Overrides (基底クラスのオーバーライド)
#---------------------------------------------------------------------
func _on_pattern_changed_impl(old_pattern: AttackPattern, new_pattern: AttackPattern) -> void:
  """パターン変更時の処理"""
  # デバッグ表示更新
  if show_debug_info and OS.is_debug_build():
    _update_debug_display()


func _on_owner_changed(new_owner: Node2D) -> void:
  """オーナー変更時の処理"""
  # デバッグ表示更新
  if show_debug_info and OS.is_debug_build():
    _update_debug_display()


func get_debug_info() -> Dictionary:
  """詳細なデバッグ情報を取得"""
  var base_info = super.get_debug_info()

  var pattern_info = {}
  if attack_pattern:
    pattern_info = {
      "pattern_type": attack_pattern.pattern_type,
      "bullet_count": attack_pattern.bullet_count,
      "is_composite": attack_pattern.is_composite_pattern(),
      "visual_config": attack_pattern.bullet_visual_config != null,
      "movement_config": attack_pattern.bullet_movement_config != null
    }

  var execution_info = {}
  if _current_execution:
    execution_info = {
      "execution_id": _current_execution.execution_id,
      "bullets_spawned": _current_execution.bullets_spawned
    }

  base_info.merge(
    {
      "pattern_info": pattern_info,
      "execution_info": execution_info,
      "override_target_group": override_target_group
    }
  )

  return base_info
