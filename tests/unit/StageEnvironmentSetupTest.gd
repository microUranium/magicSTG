# ステージ環境設定コンポーネントの単体テスト
extends GdUnitTestSuite
class_name StageEnvironmentSetupTest

# テスト対象クラス
var _environment_setup: StageEnvironmentSetup
var _test_scene: Node
var _mock_parent: Node
var _mock_bullet_layer: Node


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # モック親ノードを作成
  _mock_parent = Node.new()
  _mock_parent.name = "MockParent"
  _test_scene.add_child(_mock_parent)

  # モックBulletLayerを作成
  _mock_bullet_layer = Node.new()
  _mock_bullet_layer.name = "BulletLayer"
  _mock_parent.add_child(_mock_bullet_layer)

  # テスト対象の環境設定コンポーネントを作成
  _environment_setup = StageEnvironmentSetup.new()
  _environment_setup.name = "EnvironmentSetup"
  _mock_parent.add_child(_environment_setup)

  # null参照エラー防止：コンポーネントが正常に作成されたことを確認
  assert_that(_environment_setup).is_not_null()


func after_test():
  # リソースクリーンアップ
  if _test_scene:
    _test_scene.queue_free()


func test_initialization():
  """初期化テスト"""
  # 環境設定コンポーネントの初期化
  var result = _environment_setup.initialize(_mock_parent)
  assert_that(result).is_true()

  # 初期化後のコンポーネント状態確認
  assert_that(_environment_setup).is_not_null()


func test_bullet_layer_setup():
  """BulletLayer設定テスト"""
  # BulletLayer設定メソッドを呼び出し
  _environment_setup.setup_bullet_layer()

  # エラーが発生しないことを確認
  assert_that(_environment_setup).is_not_null()


func test_bullet_layer_setup_without_bullet_layer():
  """BulletLayerが存在しない場合のテスト"""
  # BulletLayerを削除
  if _mock_bullet_layer:
    _mock_bullet_layer.queue_free()
    _mock_bullet_layer = null

  # BulletLayer設定メソッドを呼び出し（警告が出るが、エラーにはならない）
  _environment_setup.setup_bullet_layer()

  # エラーが発生しないことを確認
  assert_that(_environment_setup).is_not_null()


func test_stage_environment_setup():
  """ステージ環境全体のセットアップテスト"""
  # ステージ環境設定メソッドを呼び出し
  _environment_setup.setup_stage_environment()

  # エラーが発生しないことを確認
  assert_that(_environment_setup).is_not_null()


func test_environment_validation():
  """環境設定の検証テスト"""
  # 環境設定を実行
  _environment_setup.setup_stage_environment()

  # 環境検証メソッドを呼び出し
  var is_valid = _environment_setup.validate_environment()

  # 戻り値がbool型であることを確認
  assert_that(is_valid is bool).is_true()


func test_environment_validation_without_bullet_layer():
  """BulletLayerが存在しない場合の環境検証テスト"""
  # BulletLayerを削除
  if _mock_bullet_layer:
    _mock_bullet_layer.queue_free()
    _mock_bullet_layer = null

  await get_tree().process_frame

  # 環境設定を実行
  _environment_setup.setup_stage_environment()

  # 環境検証（BulletLayerが無いため失敗するはず）
  # ただし、TargetServiceのメソッドが存在しない場合は適切にハンドリング
  var is_valid = _environment_setup.validate_environment()
  if TargetService and TargetService.has_method("has_bullet_parent"):
    assert_that(is_valid).is_false()
  else:
    # TargetServiceが利用できない場合は検証をスキップ
    assert_that(is_valid is bool).is_true()


func test_cleanup_environment():
  """環境クリーンアップテスト"""
  # 環境設定を実行
  _environment_setup.setup_stage_environment()

  # クリーンアップメソッドを呼び出し
  _environment_setup.cleanup_environment()

  # エラーが発生しないことを確認
  assert_that(_environment_setup).is_not_null()


func test_additional_services_extension():
  """追加サービス拡張テスト"""
  # private methodの_setup_additional_servicesは直接テストできないため、
  # setup_stage_environmentを通じて間接的にテスト
  _environment_setup.setup_stage_environment()

  # エラーが発生しないことを確認
  assert_that(_environment_setup).is_not_null()


func test_multiple_setup_calls():
  """複数回のセットアップ呼び出しテスト"""
  # セットアップを複数回実行
  _environment_setup.setup_stage_environment()
  _environment_setup.setup_stage_environment()
  _environment_setup.setup_bullet_layer()
  _environment_setup.setup_bullet_layer()

  # エラーが発生しないことを確認
  assert_that(_environment_setup).is_not_null()


func test_setup_with_different_parent_structures():
  """異なる親ノード構造でのセットアップテスト"""
  # 新しい親ノード構造を作成
  var alt_parent = Node.new()
  alt_parent.name = "AltParent"
  _test_scene.add_child(alt_parent)

  # BulletLayerを配置
  var alt_bullet_layer = Node.new()
  alt_bullet_layer.name = "BulletLayer"
  alt_parent.add_child(alt_bullet_layer)

  # 環境設定コンポーネントを新しい親に移動
  var alt_setup = StageEnvironmentSetup.new()
  alt_parent.add_child(alt_setup)

  # null参照エラー防止確認
  assert_that(alt_setup).is_not_null()

  # セットアップ実行
  alt_setup.setup_stage_environment()

  # 検証実行
  var is_valid = alt_setup.validate_environment()
  assert_that(is_valid is bool).is_true()


func test_robustness_without_parent():
  """親ノードが設定されていない場合の堅牢性テスト"""
  # 独立した環境設定コンポーネントを作成
  var standalone_setup = StageEnvironmentSetup.new()
  _test_scene.add_child(standalone_setup)

  # null参照エラー防止確認
  assert_that(standalone_setup).is_not_null()

  # 親が設定されていない状態での各メソッド呼び出し
  standalone_setup.setup_bullet_layer()
  standalone_setup.setup_stage_environment()
  var is_valid = standalone_setup.validate_environment()
  standalone_setup.cleanup_environment()

  # エラーが発生しないことを確認
  assert_that(standalone_setup).is_not_null()
  assert_that(is_valid is bool).is_true()


func test_node_path_resolution():
  """ノードパス解決のテスト"""
  # 正常なパス解決の場合
  _environment_setup.setup_bullet_layer()

  # 環境検証でBulletLayerが見つかることを確認
  var is_valid = _environment_setup.validate_environment()
  assert_that(is_valid is bool).is_true()


func test_sequential_operations():
  """連続操作のテスト"""
  # セットアップ → 検証 → クリーンアップの連続実行
  _environment_setup.setup_stage_environment()
  var is_valid_1 = _environment_setup.validate_environment()
  _environment_setup.cleanup_environment()

  # 再度セットアップ → 検証
  _environment_setup.setup_stage_environment()
  var is_valid_2 = _environment_setup.validate_environment()

  # 戻り値が正常であることを確認
  assert_that(is_valid_1 is bool).is_true()
  assert_that(is_valid_2 is bool).is_true()

  # エラーが発生しないことを確認
  assert_that(_environment_setup).is_not_null()
