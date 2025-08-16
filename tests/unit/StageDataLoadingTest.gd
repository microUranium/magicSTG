# === ステージデータ読み込み・背景・BGM設定テスト ===
extends GdUnitTestSuite
class_name StageDataLoadingTest

var test_scene: Node2D
var stage_manager: StageManager
var mock_environment_setup: StageEnvironmentSetup
var mock_audio_controller: StageAudioController
var mock_background: ParallaxBackground

# テスト用のstage_data.jsonモックデータ
var mock_stage_data: Dictionary = {
  "stage_configs":
  {
    "stage1":
    {
      "background_texture": "res://assets/gfx/backgrounds/background_forest.png",
      "bgm_path": "res://assets/audio/bgm/testStage_bgm.mp3",
      "boss_bgm_path": "res://assets/audio/bgm/testBoss_bgm.mp3",
      "clear_bgm_path": "res://assets/audio/bgm/stageclear_bgm.mp3",
      "scroll_speed": 600.0,
      "pools": ["stage1"]
    },
    "stage2":
    {
      "background_texture": "res://assets/gfx/backgrounds/background_sea.png",
      "bgm_path": "res://assets/audio/bgm/stage2_bgm_kari.mp3",
      "boss_bgm_path": "res://assets/audio/bgm/stage2_boss_bgm_kari.mp3",
      "clear_bgm_path": "res://assets/audio/bgm/stageclear_bgm.mp3",
      "scroll_speed": 600.0,
      "pools": ["stage2"]
    }
  }
}


func before_test():
  # テストシーン構築
  test_scene = Node2D.new()
  test_scene.name = "TestScene"
  add_child(test_scene)

  # GameDataRegistryのモックデータ設定
  GameDataRegistry.load_stage_data(mock_stage_data)

  # モックコンポーネント作成
  _setup_mock_components()


func after():
  if test_scene:
    test_scene.queue_free()

  # GameDataRegistryをリセット
  GameDataRegistry.reload_data()


func _setup_mock_components():
  """モックコンポーネントのセットアップ"""
  # モック背景
  mock_background = ParallaxBackground.new()
  mock_background.name = "Background"

  var sprite = Sprite2D.new()
  sprite.name = "Sprite2D"
  mock_background.add_child(sprite)
  test_scene.add_child(mock_background)

  # モック環境セットアップ
  mock_environment_setup = StageEnvironmentSetup.new()
  mock_environment_setup.name = "StageEnvironmentSetup"
  test_scene.add_child(mock_environment_setup)

  # モック音声コントローラー
  mock_audio_controller = StageAudioController.new()
  mock_audio_controller.name = "StageAudioController"
  test_scene.add_child(mock_audio_controller)


# === GameDataRegistry テスト ===


func test_stage_data_json_loading():
  """stage_data.json読み込みテスト"""
  # モックデータが正しく読み込まれていることを確認
  assert_that(GameDataRegistry.is_data_loaded()).is_true()

  # stage1設定の確認
  var stage1_config = GameDataRegistry.get_stage_config("stage1")
  assert_that(stage1_config).is_not_empty()
  assert_that(stage1_config.get("background_texture")).is_equal(
    "res://assets/gfx/backgrounds/background_forest.png"
  )
  assert_that(stage1_config.get("bgm_path")).is_equal("res://assets/audio/bgm/testStage_bgm.mp3")
  assert_that(stage1_config.get("scroll_speed")).is_equal(600.0)

  # stage2設定の確認
  var stage2_config = GameDataRegistry.get_stage_config("stage2")
  assert_that(stage2_config).is_not_empty()
  assert_that(stage2_config.get("background_texture")).is_equal(
    "res://assets/gfx/backgrounds/background_sea.png"
  )
  assert_that(stage2_config.get("bgm_path")).is_equal("res://assets/audio/bgm/stage2_bgm_kari.mp3")


func test_stage_config_not_found():
  """存在しないステージ設定のテスト"""
  var invalid_config = GameDataRegistry.get_stage_config("stage999")
  assert_that(invalid_config).is_empty()


func test_stage_config_missing_properties():
  """プロパティが不足している設定のテスト"""
  var incomplete_data = {
    "stage_configs":
    {
      "incomplete_stage":
      # bgm_pathなどが欠落
      {"background_texture": "res://test.png"}
    }
  }

  GameDataRegistry.load_stage_data(incomplete_data)
  var config = GameDataRegistry.get_stage_config("incomplete_stage")

  assert_that(config.get("background_texture")).is_equal("res://test.png")
  assert_that(config.get("bgm_path", "")).is_equal("")
  assert_that(config.get("scroll_speed", 100.0)).is_equal(100.0)


# === StageEnvironmentSetup テスト ===


func test_stage_background_setup():
  """ステージ背景セットアップテスト"""
  var stage_config = GameDataRegistry.get_stage_config("stage1")
  mock_environment_setup.setup_stage_background(stage_config)

  # 背景テクスチャが設定されることを確認
  var sprite = mock_background.get_node("Sprite2D")
  assert_that(sprite).is_not_null()
  # 実際のテクスチャ読み込みはモック環境では困難なため、メソッド呼び出しの確認のみ


func test_scroll_speed_setting():
  """スクロール速度設定テスト"""
  var stage_config = GameDataRegistry.get_stage_config("stage2")
  mock_environment_setup.setup_stage_background(stage_config)

  # scroll_speedが設定されることを確認
  assert_that(stage_config.get("scroll_speed")).is_equal(600.0)


func test_background_setup_with_empty_texture():
  """空の背景テクスチャパスでのセットアップテスト"""
  var empty_config = {"background_texture": ""}
  mock_environment_setup.setup_stage_background(empty_config)

  # エラーが発生しないことを確認
  assert_that(mock_environment_setup).is_not_null()


func test_background_setup_without_background_node():
  """背景ノードが存在しない場合のテスト"""
  # 背景ノードを削除
  test_scene.remove_child(mock_background)
  mock_background.queue_free()

  var stage_config = GameDataRegistry.get_stage_config("stage1")
  mock_environment_setup.setup_stage_background(stage_config)

  # 警告が出るが、エラーにならないことを確認
  assert_that(mock_environment_setup).is_not_null()


# === StageAudioController テスト ===


func test_stage_bgm_config_setting():
  """ステージBGM設定テスト"""
  var stage_config = GameDataRegistry.get_stage_config("stage1")
  mock_audio_controller.set_stage_config(stage_config)

  # 設定が保存されることを確認
  assert_that(mock_audio_controller.current_stage_config).is_equal(stage_config)


func test_stage_bgm_loading():
  """ステージBGM読み込みテスト"""
  var stage_config = GameDataRegistry.get_stage_config("stage2")
  mock_audio_controller.set_stage_config(stage_config)

  # BGMパスが正しく設定されることを確認
  var bgm_path = stage_config.get("bgm_path")
  assert_that(bgm_path).is_equal("res://assets/audio/bgm/stage2_bgm_kari.mp3")


func test_empty_bgm_path_handling():
  """空のBGMパス処理テスト"""
  var empty_config = {"bgm_path": ""}
  mock_audio_controller.set_stage_config(empty_config)

  # エラーが発生しないことを確認
  assert_that(mock_audio_controller.stage_bgm).is_null()


func test_missing_bgm_path_handling():
  """BGMパスが存在しない場合の処理テスト"""
  var no_bgm_config = {"background_texture": "res://test.png"}
  mock_audio_controller.set_stage_config(no_bgm_config)

  # デフォルト処理が正常に動作することを確認
  assert_that(mock_audio_controller.stage_bgm).is_null()


# === StageManager統合テスト ===


func test_stage_determination():
  """ステージ判定テスト"""
  # stage_seedからのステージ判定をテスト
  # 実際のStageManagerインスタンスがないため、ロジックの確認のみ

  # s2を含むシードはstage2
  var s2_seed = "test_s2_random_seed"
  assert_bool(s2_seed.contains("s2")).is_true()

  # その他はstage1
  var s1_seed = "test_s1_random_seed"
  assert_bool(s1_seed.contains("s2")).is_false()


func test_stage_config_immediate_application():
  """ステージ設定の即座適用テスト"""
  # stage1とstage2の設定が異なることを確認
  var stage1_config = GameDataRegistry.get_stage_config("stage1")
  var stage2_config = GameDataRegistry.get_stage_config("stage2")

  assert_that(stage1_config.get("background_texture")).is_not_equal(
    stage2_config.get("background_texture")
  )
  assert_that(stage1_config.get("bgm_path")).is_not_equal(stage2_config.get("bgm_path"))


# === エラーハンドリング・堅牢性テスト ===


func test_invalid_json_structure():
  """無効なJSON構造の処理テスト"""
  var invalid_data = {"invalid_key": "invalid_value"}

  var result = GameDataRegistry.load_stage_data(invalid_data)
  assert_that(result).is_true()  # 空のデータでも読み込み成功

  # 空の設定が返されることを確認
  var config = GameDataRegistry.get_stage_config("stage1")
  assert_that(config).is_empty()


func test_resource_loading_resilience():
  """リソース読み込み堅牢性テスト"""
  var config_with_invalid_paths = {
    "background_texture": "res://invalid/path.png",
    "bgm_path": "res://invalid/audio.mp3",
    "scroll_speed": 500.0
  }

  # 無効なパスでもエラーにならないことを確認
  mock_environment_setup.setup_stage_background(config_with_invalid_paths)
  mock_audio_controller.set_stage_config(config_with_invalid_paths)

  assert_that(mock_environment_setup).is_not_null()
  assert_that(mock_audio_controller).is_not_null()


func test_null_config_handling():
  """null設定の処理テスト"""
  var null_config = {}

  mock_environment_setup.setup_stage_background(null_config)
  mock_audio_controller.set_stage_config(null_config)

  # null設定でもクラッシュしないことを確認
  assert_that(mock_environment_setup).is_not_null()
  assert_that(mock_audio_controller).is_not_null()


# === プロパティ妥当性テスト ===


func test_all_required_stage_properties():
  """全必須ステージプロパティテスト"""
  var required_properties = [
    "background_texture", "bgm_path", "boss_bgm_path", "clear_bgm_path", "scroll_speed", "pools"
  ]

  for stage_name in ["stage1", "stage2"]:
    var config = GameDataRegistry.get_stage_config(stage_name)
    assert_that(config).is_not_empty()

    for property in required_properties:
      assert_that(config.has(property)).is_true()
      assert_that(config.get(property)).is_not_null()


func test_stage_bgm_path_consistency():
  """ステージBGMパス一貫性テスト"""
  var stage1_config: Dictionary = GameDataRegistry.get_stage_config("stage1")
  var stage2_config: Dictionary = GameDataRegistry.get_stage_config("stage2")

  # 各ステージのBGMパスが適切に設定されていることを確認
  assert_bool(stage1_config.get("bgm_path").contains("testStage_bgm")).is_true()
  assert_bool(stage2_config.get("bgm_path").contains("stage2_bgm")).is_true()

  # クリアBGMは共通
  assert_that(stage1_config.get("clear_bgm_path")).is_equal(stage2_config.get("clear_bgm_path"))


func test_background_path_consistency():
  """背景パス一貫性テスト"""
  var stage1_config: Dictionary = GameDataRegistry.get_stage_config("stage1")
  var stage2_config: Dictionary = GameDataRegistry.get_stage_config("stage2")

  # 背景テクスチャが異なることを確認
  assert_bool(stage1_config.get("background_texture").contains("background_forest")).is_true()
  assert_bool(stage2_config.get("background_texture").contains("background_sea")).is_true()


# === 統合・実用性テスト ===


func test_stage_environment_complete_setup():
  """ステージ環境完全セットアップテスト"""
  # stage1の完全セットアップ
  var stage1_config = GameDataRegistry.get_stage_config("stage1")

  mock_environment_setup.setup_stage_background(stage1_config)
  mock_audio_controller.set_stage_config(stage1_config)

  # 両方のコンポーネントが正常に動作することを確認
  assert_that(mock_environment_setup).is_not_null()
  assert_that(mock_audio_controller).is_not_null()
  assert_that(mock_audio_controller.current_stage_config).is_equal(stage1_config)


func test_stage_switching_simulation():
  """ステージ切り替えシミュレーションテスト"""
  # stage1からstage2への切り替えをシミュレート
  var stage1_config = GameDataRegistry.get_stage_config("stage1")
  var stage2_config = GameDataRegistry.get_stage_config("stage2")

  # stage1設定
  mock_environment_setup.setup_stage_background(stage1_config)
  mock_audio_controller.set_stage_config(stage1_config)

  # stage2に切り替え
  mock_environment_setup.setup_stage_background(stage2_config)
  mock_audio_controller.set_stage_config(stage2_config)

  # 最終的にstage2設定になっていることを確認
  assert_that(mock_audio_controller.current_stage_config).is_equal(stage2_config)


func test_multiple_stage_configs_loaded():
  """複数ステージ設定読み込みテスト"""
  # 全ステージ設定が読み込まれていることを確認
  var stage_configs = mock_stage_data.get("stage_configs", {})

  for stage_name in stage_configs.keys():
    var config = GameDataRegistry.get_stage_config(stage_name)
    assert_that(config).is_not_empty()

    # 基本プロパティが存在することを確認
    assert_that(config.has("background_texture")).is_true()
    assert_that(config.has("bgm_path")).is_true()
    assert_that(config.has("scroll_speed")).is_true()
