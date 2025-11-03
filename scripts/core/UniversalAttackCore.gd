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
var _beam_duration_timer: SceneTreeTimer = null  # ビーム持続時間タイマー
var _spawned_projectiles: Array[Node] = []  # 生成した弾丸/ビームの追跡
var _rear_firing_mode: bool = false  # 後方発射モード
var _base_dir_cached: Vector2 = Vector2.ZERO  # ベース方向のキャッシュ


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
  super._ready()
  if debug_display:
    debug_display.visible = show_debug_info and OS.is_debug_build()
  _register_pattern_executors()


func _process(_delta: float) -> void:
  _update_gauge_display()


func _update_gauge_display() -> void:
  """ゲージ表示の更新（プレイヤーモード時のみ）"""
  if not player_mode or not show_gauge_ui:
    return

  # ビーム発射中の場合
  if (
    _beam_duration_timer
    and attack_pattern
    and attack_pattern.pattern_type == AttackPattern.PatternType.BEAM
  ):
    var elapsed = _beam_duration_timer.time_left
    var progress = (elapsed) * 100 / attack_pattern.beam_duration
    set_gauge(progress)
  # 通常のクールダウン中の場合
  elif _cool_timer and _cooling:
    var elapsed = _cool_timer.time_left
    var progress = (cooldown_sec - elapsed) * 100 / cooldown_sec
    set_gauge(progress)


func _register_pattern_executors() -> void:
  """パターン実行器を登録"""
  _pattern_executors[AttackPattern.PatternType.SINGLE_SHOT] = _execute_single_shot
  _pattern_executors[AttackPattern.PatternType.RAPID_FIRE] = _execute_rapid_fire
  _pattern_executors[AttackPattern.PatternType.BARRIER_BULLETS] = _execute_barrier_bullets
  _pattern_executors[AttackPattern.PatternType.SPIRAL] = _execute_spiral
  _pattern_executors[AttackPattern.PatternType.BEAM] = _execute_beam
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

  # 警告表示（warning_configが存在する場合のみ）
  if !attack_pattern.warning_configs.is_empty():
    _base_dir_cached = await _show_attack_warning()

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

  if not attack_pattern:
    push_warning("UniversalAttackCore: Attack pattern is not set.")
    return false

  # ビームパターンの場合はbeam_sceneをチェック、それ以外はbullet_sceneをチェック
  if attack_pattern.pattern_type == AttackPattern.PatternType.BEAM:
    if not attack_pattern.beam_scene:
      push_warning("UniversalAttackCore: Beam pattern has no beam scene.")
      return false
  else:
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
    if attack_pattern.pattern_layers.size() <= i:
      return false
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
  var base_dir = pattern.calculate_base_direction(
    _owner_actor.global_position, target_pos, _rear_firing_mode
  )

  var success = true
  for i in range(pattern.bullet_count):
    var bullet_dir
    if pattern.direction_type == AttackPattern.DirectionType.CIRCLE:
      # 円形配置の場合、方向を計算
      bullet_dir = pattern.calculate_circle_direction(i, pattern.bullet_count, base_dir)
    elif pattern.direction_type == AttackPattern.DirectionType.RANDOM:
      # RANDOMタイプの場合、不等間隔発射（扇状設定の有無は内部で判定）
      bullet_dir = pattern.calculate_random_spread_direction(base_dir)
    else:
      # 通常の方向計算
      bullet_dir = pattern.calculate_spread_direction(i, pattern.bullet_count, base_dir)
    if not _spawn_bullet(pattern, bullet_dir, _owner_actor.global_position, i):
      success = false

  if is_inside_tree():
    await get_tree().process_frame

  return success


func _execute_rapid_fire(pattern: AttackPattern) -> bool:
  """連射"""
  var target_pos = _get_player_position()
  var success = true

  for burst in range(pattern.rapid_fire_count):
    if pattern.angle_spread > 0 and pattern.direction_type == AttackPattern.DirectionType.FIXED:
      # 角度スプレッドがある場合はランダム方向を計算
      var base_dir = pattern.calculate_base_direction(
        _owner_actor.global_position, target_pos, _rear_firing_mode
      )
      var bullet_dir = pattern.calculate_spread_direction(burst, pattern.rapid_fire_count, base_dir)
      if not _spawn_bullet(pattern, bullet_dir, _owner_actor.global_position, burst):
        success = false
    elif not await _execute_single_shot(pattern):
      success = false

    if burst < pattern.rapid_fire_count - 1:
      if is_inside_tree():
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
  var base_dir = pattern.calculate_base_direction(
    _owner_actor.global_position, target_pos, _rear_firing_mode
  )

  var success = true
  for i in range(pattern.bullet_count):
    # 螺旋の角度計算
    var spiral_angle = (TAU / pattern.bullet_count) * i
    var bullet_dir = base_dir.rotated(spiral_angle)

    if not _spawn_bullet(pattern, bullet_dir, _owner_actor.global_position, i):
      success = false

    # 螺旋の時間差
    await get_tree().create_timer(0.05).timeout

  return success


func _execute_beam(pattern: AttackPattern) -> bool:
  """ビーム攻撃（複数ビーム対応）"""
  if not pattern.beam_scene:
    push_warning("UniversalAttackCore: Beam pattern has no beam scene.")
    return false

  var parent = _find_bullet_parent()
  if not parent:
    push_warning("UniversalAttackCore: No valid parent node found for beam.")
    return false

  # エンチャント適用済み値で初期化
  var modified_duration = pattern.beam_duration
  var modified_damage = pattern.damage
  var beam_count = max(1, pattern.bullet_count)  # bullet_countを使用

  # ターゲットグループ設定
  var target_group = (
    override_target_group if not override_target_group.is_empty() else pattern.target_group
  )

  # 複数ビームの生成
  var created_beams: Array[Node] = []

  for i in range(beam_count):
    var beam_instance = pattern.beam_scene.instantiate()
    parent.add_child(beam_instance)

    if _owner_actor:
      beam_instance.global_position = _owner_actor.global_position
    else:
      push_warning("UniversalAttackCore: Owner actor is not set for beam.")

    # 視覚・動作設定の適用
    _apply_bullet_configs(beam_instance, pattern)

    # ビーム方向の計算（複数ビーム対応）
    var beam_direction = _calculate_multi_beam_direction(pattern, i, beam_count)

    # ビーム専用初期化（方向を含む）
    if beam_instance.has_method("initialize"):
      beam_instance.initialize(_owner_actor, modified_damage, beam_direction, pattern.beam_offset)

    # 方向設定メソッドがある場合は個別に設定
    if beam_instance.has_method("set_beam_direction"):
      beam_instance.set_beam_direction(beam_direction)

    # ターゲットグループ設定
    if beam_instance.has_method("set_target_group"):
      beam_instance.set_target_group(target_group)

    # ビーム視覚設定の適用
    if pattern.beam_visual_config and beam_instance.has_method("apply_visual_config"):
      beam_instance.apply_visual_config(pattern.beam_visual_config)

    # 生成したビームを追跡リストに追加
    _spawned_projectiles.append(beam_instance)
    beam_instance.tree_exiting.connect(_on_projectile_destroyed.bind(beam_instance))
    created_beams.append(beam_instance)

  # ビーム持続時間タイマーを設定（ゲージ表示用）
  _beam_duration_timer = get_tree().create_timer(modified_duration)

  # プレイヤーモード時はゲージをリセット
  if player_mode and show_gauge_ui:
    set_gauge(0)

  # 一定時間後にビームを削除
  await _beam_duration_timer.timeout
  for beam in created_beams:
    if is_instance_valid(beam):
      beam.queue_free()

  _beam_duration_timer = null
  return true


func _calculate_multi_beam_direction(
  pattern: AttackPattern, beam_index: int, total_beams: int
) -> Vector2:
  """複数ビーム用の方向計算"""
  var base_direction: Vector2
  # ベース方向を取得
  if pattern.warning_configs.size() > 0:
    base_direction = _base_dir_cached
  else:
    var target_pos = _get_player_position()
    base_direction = pattern.calculate_base_direction(
      _owner_actor.global_position, target_pos, _rear_firing_mode
    )

  # 単発ビームの場合はそのまま返す
  if total_beams == 1:
    return base_direction

  var angle_offset_rad = 0.0

  if pattern.direction_type == AttackPattern.DirectionType.CIRCLE:
    # 円形配置：360度を等分
    var angle_step = (2.0 * PI) / total_beams
    angle_offset_rad = beam_index * angle_step + deg_to_rad(pattern.angle_offset)
  else:
    # 扇形配置：angle_spreadを等分
    if total_beams > 1:
      var spread_rad = deg_to_rad(pattern.angle_spread)
      var angle_step = spread_rad / (total_beams - 1)
      angle_offset_rad = -spread_rad / 2.0 + beam_index * angle_step

    # angle_offsetを適用
    angle_offset_rad += deg_to_rad(pattern.angle_offset)

  # 方向を回転
  return base_direction.rotated(angle_offset_rad).normalized()


func _get_base_direction(pattern: AttackPattern) -> Vector2:
  """ベース方向の取得"""
  # 方向の上書き指定がある場合はそれを使用
  if pattern.beam_direction_override != Vector2.ZERO:
    return pattern.beam_direction_override.normalized()

  # DirectionType に基づいて方向を計算
  var direction = Vector2.ZERO

  match pattern.direction_type:
    AttackPattern.DirectionType.FIXED:
      direction = pattern.base_direction
      if _rear_firing_mode:
        direction = -direction
    AttackPattern.DirectionType.TO_PLAYER:
      var player_pos = _get_player_position()
      if player_pos != Vector2.ZERO and _owner_actor:
        direction = (player_pos - _owner_actor.global_position).normalized()
      else:
        direction = pattern.base_direction
    AttackPattern.DirectionType.RANDOM:
      var angle = randf() * 2 * PI
      direction = Vector2(cos(angle), sin(angle))
      if _rear_firing_mode:
        direction = -direction
    AttackPattern.DirectionType.CIRCLE, AttackPattern.DirectionType.CUSTOM:
      # 円形やカスタムの場合はデフォルト方向
      direction = pattern.base_direction
      if _rear_firing_mode:
        direction = -direction

  return direction.normalized() if direction != Vector2.ZERO else Vector2.UP


func _execute_custom(pattern: AttackPattern) -> bool:
  """カスタムパターン"""
  if pattern.custom_script and pattern.custom_script.has_method("execute_pattern"):
    return await pattern.custom_script.execute_pattern(self, pattern, _owner_actor)
  else:
    push_warning("UniversalAttackCore: Custom pattern has no execute_pattern method.")
    await get_tree().process_frame
    return false


# === ヘルパーメソッド ===


func _spawn_bullet(
  pattern: AttackPattern, direction: Vector2, spawn_pos: Vector2, bullet_index: int = -1
) -> bool:
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
  bullet.bullet_range = pattern.bullet_range
  bullet.bullet_lifetime = pattern.bullet_lifetime
  if "penetration_count" in bullet:
    bullet.penetration_count = pattern.penetration_count

  # ターゲットグループ設定
  var target_group = (
    override_target_group if not override_target_group.is_empty() else pattern.target_group
  )
  bullet.target_group = target_group

  # persist_offscreen設定の適用
  if "persist_offscreen" in bullet:
    bullet.persist_offscreen = pattern.persist_offscreen
    bullet.max_offscreen_distance = pattern.max_offscreen_distance
    bullet.forced_lifetime = pattern.forced_lifetime

  # 視覚・動作設定の適用
  _apply_bullet_configs(bullet, pattern, bullet_index)

  # 生成した弾丸を追跡リストに追加
  _spawned_projectiles.append(bullet)
  bullet.tree_exiting.connect(_on_projectile_destroyed.bind(bullet))

  # 実行コンテキスト更新
  if _current_execution:
    _current_execution.bullets_spawned += 1

  # プレイヤーモード時は発射時にゲージをリセット
  if player_mode and show_gauge_ui:
    set_gauge(0)

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
    var modified_damage = pattern.damage
    var modified_radius = pattern.circle_radius
    bullet.setup_barrier_bullet(
      _owner_actor,
      group_id,
      pattern.bullet_count,
      index,
      _get_player_node(),
      modified_radius,
      modified_damage,
      pattern.target_group
    )

  # 生成したバリア弾を追跡リストに追加
  _spawned_projectiles.append(bullet)
  bullet.tree_exiting.connect(_on_projectile_destroyed.bind(bullet))

  return bullet


func _start_barrier_bullet(bullet, pattern: AttackPattern):
  """バリア弾の開始処理"""
  if bullet.has_method("start_rotation"):
    bullet.start_rotation(pattern.rotation_duration, pattern.rotation_speed)


func _apply_bullet_configs(bullet: Node, pattern: AttackPattern, bullet_index: int = -1):
  """弾丸に視覚・動作設定を適用"""
  # 貫通設定の適用
  if "penetration_count" in bullet:
    bullet.penetration_count = pattern.penetration_count

  # 視覚設定の適用
  if pattern.bullet_visual_config and bullet.has_method("apply_visual_config"):
    bullet.apply_visual_config(pattern.bullet_visual_config)

  # 動作設定の適用
  if pattern.bullet_movement_config and bullet.has_method("apply_movement_config"):
    # 螺旋移動の場合、インデックスに応じて位相オフセットを設定
    if (
      bullet_index >= 0
      and pattern.bullet_movement_config.movement_type == BulletMovementConfig.MovementType.SPIRAL
      and pattern.direction_type == AttackPattern.DirectionType.CIRCLE
      and pattern.bullet_count > 0
    ):
      # movement_configを複製して位相オフセットを設定
      var modified_config = pattern.bullet_movement_config.duplicate()
      var phase_step = 360.0 / pattern.bullet_count
      modified_config.spiral_phase_offset += bullet_index * phase_step
      bullet.apply_movement_config(modified_config)
    else:
      bullet.apply_movement_config(pattern.bullet_movement_config)

  # バリア弾の動作設定
  if pattern.barrier_movement_config and bullet.has_method("apply_barrier_movement_config"):
    bullet.apply_barrier_movement_config(pattern.barrier_movement_config)


func _get_player_position() -> Vector2:
  return TargetService.get_player_position()


func _get_player_node() -> Node2D:
  return TargetService.get_player()


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
  if not debug_label or not attack_pattern:
    return

  var pattern_name = attack_pattern.resource_path.get_file().get_basename()
  var execution_info = ""
  if _current_execution:
    execution_info = "\nBullets: %d" % _current_execution.bullets_spawned

  var enchant_info = ""
  if player_mode and item_inst and item_inst.enchantments.size() > 0:
    enchant_info = "\nEnchants: %d" % item_inst.enchantments.size()

  debug_label.text = (
    "Pattern: %s\nCount: %d\nDamage: %d%s%s"
    % [
      pattern_name, attack_pattern.bullet_count, attack_pattern.damage, execution_info, enchant_info
    ]
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


func _on_projectile_destroyed(projectile: Node) -> void:
  _spawned_projectiles.erase(projectile)


func _show_attack_warning() -> Vector2:
  var max_duration: float = 0.0
  var player_pos = _get_player_position()
  var base_dir = attack_pattern.calculate_base_direction(
    _owner_actor.global_position, player_pos, _rear_firing_mode
  )

  # 各警告設定に対して警告線を生成
  for warning_config in attack_pattern.warning_configs:
    var warning_scene = preload("res://scenes/effects/attack_warning.tscn")
    var warning = warning_scene.instantiate()
    get_tree().current_scene.add_child(warning)

    # 警告線の開始座標を計算
    var start_pos: Vector2
    start_pos = warning_config.position_offset

    # 警告線の終点座標を計算（角度を使用）
    var angle_rad = base_dir.angle()
    var direction = Vector2(cos(angle_rad), sin(angle_rad))
    var end_pos = start_pos + direction * warning_config.warning_length

    # 警告線を初期化（相対座標の場合はowner_actorを渡す）
    warning.initialize(
      start_pos,
      end_pos,
      warning_config,
      _owner_actor if warning_config.use_relative_position else null
    )

    # 最長の警告時間を記録
    max_duration = max(max_duration, warning_config.warning_duration)

  # 最長の警告時間だけ待機
  if max_duration > 0.0:
    await get_tree().create_timer(max_duration).timeout

  return base_dir


func cleanup_on_death() -> void:
  for projectile in _spawned_projectiles:
    if is_instance_valid(projectile):
      projectile.queue_free()
  _spawned_projectiles.clear()
  _beam_duration_timer = null


func set_rear_firing_mode(enabled: bool) -> void:
  """後方発射モードの設定"""
  _rear_firing_mode = enabled
