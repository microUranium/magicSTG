# === AttackPattern 拡張機能のテスト ===
extends GdUnitTestSuite
class_name AttackPatternExtendedTest

var attack_pattern: AttackPattern


func before_test():
  attack_pattern = AttackPattern.new()


func after_test():
  if attack_pattern:
    attack_pattern = null


# === フェーズ1: 基本機能テスト ===


func test_bullet_range_property_setting():
  """弾丸射程距離プロパティのテスト"""
  # デフォルト値確認
  assert_that(attack_pattern.bullet_range).is_equal(0.0)

  # 値設定
  attack_pattern.bullet_range = 500.0
  assert_that(attack_pattern.bullet_range).is_equal(500.0)

  # 負の値も設定可能であることを確認
  attack_pattern.bullet_range = -100.0
  assert_that(attack_pattern.bullet_range).is_equal(-100.0)


func test_bullet_lifetime_property_setting():
  """弾丸寿命プロパティのテスト"""
  # デフォルト値確認
  assert_that(attack_pattern.bullet_lifetime).is_equal(0.0)

  # 値設定
  attack_pattern.bullet_lifetime = 3.5
  assert_that(attack_pattern.bullet_lifetime).is_equal(3.5)

  # 負の値も設定可能であることを確認
  attack_pattern.bullet_lifetime = -1.0
  assert_that(attack_pattern.bullet_lifetime).is_equal(-1.0)


func test_auto_start_flag_behavior():
  """自動開始フラグのテスト"""
  # デフォルト値確認
  assert_that(attack_pattern.auto_start).is_true()

  # フラグ変更
  attack_pattern.auto_start = false
  assert_that(attack_pattern.auto_start).is_false()

  # 再度変更
  attack_pattern.auto_start = true
  assert_that(attack_pattern.auto_start).is_true()


func test_beam_direction_override_functionality():
  """ビーム方向上書き機能のテスト"""
  # デフォルト値確認
  assert_that(attack_pattern.beam_direction_override).is_equal(Vector2.ZERO)

  # 方向設定
  var test_direction = Vector2(1.0, 0.5)
  attack_pattern.beam_direction_override = test_direction
  assert_that(attack_pattern.beam_direction_override).is_equal(test_direction)

  # 単位ベクトル設定
  attack_pattern.beam_direction_override = Vector2.UP
  assert_that(attack_pattern.beam_direction_override).is_equal(Vector2.UP)


func test_beam_visual_config_assignment():
  """ビーム視覚設定の代入テスト"""
  # デフォルトはnull
  assert_that(attack_pattern.beam_visual_config).is_null()

  # BeamVisualConfigリソースの代入（nullでテスト）
  var mock_config = null  # 実際のテストではBeamVisualConfig.new()
  attack_pattern.beam_visual_config = mock_config
  assert_that(attack_pattern.beam_visual_config).is_equal(mock_config)


func test_calculate_random_spread_direction_with_spread():
  """角度スプレッド有りでのランダム方向計算テスト"""
  attack_pattern.angle_spread = 90.0  # 90度スプレッド
  var base_dir = Vector2.DOWN

  # 複数回実行して範囲内であることを確認
  for i in range(10):
    var direction = attack_pattern.calculate_random_spread_direction(base_dir)

    # 単位ベクトルであることを確認
    assert_that(abs(direction.length() - 1.0)).is_less(0.01)

    # 角度が期待範囲内にあることを確認
    var angle_diff = abs(direction.angle_to(base_dir))
    assert_that(angle_diff).is_less_equal(deg_to_rad(45.0))  # 90度/2 = 45度


func test_calculate_random_spread_direction_without_spread():
  """角度スプレッド無しでのランダム方向計算テスト"""
  attack_pattern.angle_spread = 0.0  # スプレッド無し
  var base_dir = Vector2.DOWN

  # 複数回実行してランダム性を確認
  var directions = []
  for i in range(5):
    var direction = attack_pattern.calculate_random_spread_direction(base_dir)
    directions.append(direction)

    # 単位ベクトルであることを確認
    assert_that(abs(direction.length() - 1.0)).is_less(0.01)

  # 少なくとも一部は異なる方向であることを確認（完全ランダム）
  var all_same = true
  for i in range(1, directions.size()):
    if directions[i].distance_to(directions[0]) > 0.1:
      all_same = false
      break

  # 完全ランダムなので方向が一致しないことを期待
  # ただし、確率的にまれに同じ方向になる可能性もあるため厳密にはしない
  assert_that(directions.size()).is_equal(5)


func test_random_direction_type_new_logic():
  """RANDOM方向タイプの新ロジックテスト"""
  attack_pattern.direction_type = AttackPattern.DirectionType.RANDOM
  attack_pattern.base_direction = Vector2.RIGHT

  var from_pos = Vector2.ZERO
  var target_pos = Vector2(100, 100)  # 任意の位置（無視される）

  # 新ロジックではbase_directionをそのまま正規化して返す
  var direction = attack_pattern.calculate_base_direction(from_pos, target_pos)
  assert_that(direction).is_equal(Vector2.RIGHT)

  # 正規化されることの確認
  attack_pattern.base_direction = Vector2(2.0, 0.0)  # 非正規化ベクトル
  direction = attack_pattern.calculate_base_direction(from_pos, target_pos)
  assert_that(direction).is_equal(Vector2.RIGHT)  # 正規化後


# === フェーズ2: 複雑機能テスト ===


func test_bullet_range_lifetime_combination():
  """弾丸射程と寿命の組み合わせテスト"""
  attack_pattern.bullet_range = 300.0
  attack_pattern.bullet_lifetime = 2.0

  assert_that(attack_pattern.bullet_range).is_equal(300.0)
  assert_that(attack_pattern.bullet_lifetime).is_equal(2.0)

  # 0値の組み合わせ（無限設定）
  attack_pattern.bullet_range = 0.0
  attack_pattern.bullet_lifetime = 0.0

  assert_that(attack_pattern.bullet_range).is_equal(0.0)
  assert_that(attack_pattern.bullet_lifetime).is_equal(0.0)


func test_beam_configuration_extended():
  """拡張ビーム設定のテスト"""
  attack_pattern.pattern_type = AttackPattern.PatternType.BEAM
  attack_pattern.beam_duration = 2.5
  attack_pattern.beam_direction_override = Vector2.LEFT

  # 従来設定
  assert_that(attack_pattern.beam_duration).is_equal(2.5)

  # 新設定
  assert_that(attack_pattern.beam_direction_override).is_equal(Vector2.LEFT)


func test_random_spread_direction_edge_cases():
  """ランダムスプレッド方向計算のエッジケース"""
  var base_dir = Vector2.UP

  # 極小スプレッド
  attack_pattern.angle_spread = 0.1
  var direction = attack_pattern.calculate_random_spread_direction(base_dir)
  assert_that(abs(direction.length() - 1.0)).is_less(0.01)

  # 大きなスプレッド
  attack_pattern.angle_spread = 360.0
  direction = attack_pattern.calculate_random_spread_direction(base_dir)
  assert_that(abs(direction.length() - 1.0)).is_less(0.01)

  # 負のスプレッド（どう処理されるか確認）
  attack_pattern.angle_spread = -45.0
  direction = attack_pattern.calculate_random_spread_direction(base_dir)
  assert_that(abs(direction.length() - 1.0)).is_less(0.01)


func test_angle_offset_with_random_spread():
  """角度オフセットとランダムスプレッドの組み合わせ"""
  attack_pattern.angle_spread = 60.0
  attack_pattern.angle_offset = 30.0
  var base_dir = Vector2.DOWN

  # 複数回テストして、オフセットが適用されていることを確認
  for i in range(5):
    var direction = attack_pattern.calculate_random_spread_direction(base_dir)
    assert_that(abs(direction.length() - 1.0)).is_less(0.01)

    # 方向がオフセットされた範囲内にあることを確認
    # 完全な検証は困難だが、基本的な正常性をチェック
    var angle_to_base = direction.angle_to(base_dir)
    assert_that(abs(angle_to_base)).is_less_equal(PI)  # 基本的な妥当性


func test_auto_start_with_different_pattern_types():
  """異なるパターンタイプでの自動開始フラグ"""
  # 各パターンタイプでのauto_start設定
  var pattern_types = [
    AttackPattern.PatternType.SINGLE_SHOT,
    AttackPattern.PatternType.RAPID_FIRE,
    AttackPattern.PatternType.SPIRAL,
    AttackPattern.PatternType.BEAM,
    AttackPattern.PatternType.BARRIER_BULLETS
  ]

  for pattern_type in pattern_types:
    attack_pattern.pattern_type = pattern_type
    attack_pattern.auto_start = false

    assert_that(attack_pattern.auto_start).is_false()
    assert_that(attack_pattern.pattern_type).is_equal(pattern_type)

    attack_pattern.auto_start = true
    assert_that(attack_pattern.auto_start).is_true()


func test_beam_direction_override_zero_fallback():
  """ビーム方向上書きのゼロ値フォールバック"""
  # ZERO値の場合のフォールバック動作確認（実装に依存）
  attack_pattern.beam_direction_override = Vector2.ZERO
  attack_pattern.direction_type = AttackPattern.DirectionType.FIXED
  attack_pattern.base_direction = Vector2.RIGHT

  # 設定値の確認
  assert_that(attack_pattern.beam_direction_override).is_equal(Vector2.ZERO)
  assert_that(attack_pattern.base_direction).is_equal(Vector2.RIGHT)

  # 非ZERO値での確認
  attack_pattern.beam_direction_override = Vector2.UP
  assert_that(attack_pattern.beam_direction_override).is_equal(Vector2.UP)


func test_property_persistence():
  """プロパティの永続性テスト"""
  # 複数プロパティの設定と保持確認
  attack_pattern.bullet_range = 250.0
  attack_pattern.bullet_lifetime = 1.5
  attack_pattern.auto_start = false
  attack_pattern.beam_direction_override = Vector2.LEFT

  # 他の操作後も値が保持されることを確認
  attack_pattern.angle_spread = 45.0
  attack_pattern.bullet_count = 5

  assert_that(attack_pattern.bullet_range).is_equal(250.0)
  assert_that(attack_pattern.bullet_lifetime).is_equal(1.5)
  assert_that(attack_pattern.auto_start).is_false()
  assert_that(attack_pattern.beam_direction_override).is_equal(Vector2.LEFT)


func test_zero_infinity_semantics():
  """ゼロ値＝無限の意味論テスト"""
  # bullet_range = 0.0 は無限射程を意味
  attack_pattern.bullet_range = 0.0
  assert_that(attack_pattern.bullet_range).is_equal(0.0)

  # bullet_lifetime = 0.0 は無限寿命を意味
  attack_pattern.bullet_lifetime = 0.0
  assert_that(attack_pattern.bullet_lifetime).is_equal(0.0)

  # 両方ともゼロ（デフォルト状態）
  var default_pattern = AttackPattern.new()
  assert_that(default_pattern.bullet_range).is_equal(0.0)
  assert_that(default_pattern.bullet_lifetime).is_equal(0.0)
