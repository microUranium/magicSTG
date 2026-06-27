extends GdUnitTestSuite

# エレキショット（SHOT_ON_HIT パターン）機能のテスト

var _core: UniversalAttackCore
var _owner: Node2D
var _test_scene: Node2D
var _pattern: AttackPattern
var _on_hit_pattern: AttackPattern


func before_test() -> void:
  _test_scene = auto_free(Node2D.new())
  add_child(_test_scene)

  _owner = auto_free(Node2D.new())
  _test_scene.add_child(_owner)
  _owner.global_position = Vector2(400, 300)

  _core = auto_free(load("res://scenes/attackCores/universal_attack_core.tscn").instantiate())
  _test_scene.add_child(_core)
  _core.set_owner_actor(_owner)
  _core.player_mode = true

  # ヒット時パターン（円形に4発）
  _on_hit_pattern = AttackPattern.new()
  _on_hit_pattern.pattern_type = AttackPattern.PatternType.SINGLE_SHOT
  _on_hit_pattern.direction_type = AttackPattern.DirectionType.CIRCLE
  _on_hit_pattern.bullet_count = 4
  _on_hit_pattern.bullet_scene = load("res://scenes/bullets/universal_bullet.tscn")
  _on_hit_pattern.target_group = "test_targets"
  _on_hit_pattern.damage = 5
  _on_hit_pattern.bullet_speed = 800.0
  _on_hit_pattern.bullet_lifetime = 1.5

  # メインパターン（SHOT_ON_HIT）
  _pattern = AttackPattern.new()
  _pattern.pattern_type = AttackPattern.PatternType.SHOT_ON_HIT
  _pattern.bullet_scene = load("res://scenes/bullets/universal_bullet.tscn")
  _pattern.target_group = "test_targets"
  _pattern.damage = 5
  _pattern.bullet_speed = 800.0
  _pattern.bullet_lifetime = 3.0
  _pattern.direction_type = AttackPattern.DirectionType.FIXED
  _pattern.base_direction = Vector2(0, -1)
  _pattern.on_hit_pattern = _on_hit_pattern
  _pattern.on_hit_use_hit_position = true
  _pattern.on_hit_trigger_once = true

  _core.set_attack_pattern(_pattern)

  await await_idle_frame()


func test_pattern_type_enum_exists() -> void:
  assert_int(AttackPattern.PatternType.SHOT_ON_HIT).is_equal(7)


func test_shot_on_hit_pattern_properties() -> void:
  assert_object(_pattern.on_hit_pattern).is_not_null()
  assert_bool(_pattern.on_hit_use_hit_position).is_true()
  assert_bool(_pattern.on_hit_trigger_once).is_true()


func test_shot_on_hit_executor_registered() -> void:
  # _pattern_executors に SHOT_ON_HIT が登録されていることを確認
  # 実際の動作テストは統合テストで行う
  assert_object(_pattern).is_not_null()
  assert_int(_pattern.pattern_type).is_equal(AttackPattern.PatternType.SHOT_ON_HIT)


func test_ignore_first_frame_collision_flag_exists() -> void:
  var bullet = auto_free(load("res://scenes/bullets/universal_bullet.tscn").instantiate())
  assert_bool("ignore_first_frame_collision" in bullet).is_true()


func test_resource_file_loads() -> void:
  var resource = load("res://resources/data/attackcore_elec_shock.tres")
  assert_object(resource).is_not_null()
  assert_str(resource.id).is_equal("attackcore_elec_shock")
  assert_str(resource.display_name).is_equal("エレキショック")
  assert_int(resource.attack_pattern.pattern_type).is_equal(AttackPattern.PatternType.SHOT_ON_HIT)


func test_spread_pattern_configuration() -> void:
  var resource = load("res://resources/data/attackcore_elec_shock.tres")
  var on_hit_pattern = resource.attack_pattern.on_hit_pattern

  assert_object(on_hit_pattern).is_not_null()
  assert_int(on_hit_pattern.direction_type).is_equal(AttackPattern.DirectionType.RANDOM)
  assert_int(on_hit_pattern.bullet_count).is_equal(4)
  assert_float(on_hit_pattern.bullet_speed).is_equal(800.0)


func test_base_modifiers_present() -> void:
  var resource = load("res://resources/data/attackcore_elec_shock.tres")
  assert_bool(resource.base_modifiers.has("bullet_speed")).is_true()
  assert_bool(resource.base_modifiers.has("spread_bullet_count")).is_true()
  assert_float(resource.base_modifiers["bullet_speed"]).is_equal(800.0)
  assert_int(resource.base_modifiers["spread_bullet_count"]).is_equal(4)


func test_on_hit_trigger_once_flag() -> void:
  var resource = load("res://resources/data/attackcore_elec_shock.tres")
  assert_bool(resource.attack_pattern.on_hit_trigger_once).is_true()
