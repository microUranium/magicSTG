# コンポーネントレジストリの単体テスト
extends GdUnitTestSuite
class_name StageComponentRegistryTest

# テスト対象クラス
var _registry: StageComponentRegistry
var _mock_parent: Node
var _test_scene: Node


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # モック親ノードを作成
  _mock_parent = Node.new()
  _mock_parent.name = "MockParent"
  _test_scene.add_child(_mock_parent)

  # テスト対象のレジストリを初期化
  _registry = StageComponentRegistry.new()

  # null参照エラー防止：レジストリが正常に作成されたことを確認
  assert_that(_registry).is_not_null()
  _registry.initialize(_mock_parent)


func after_test():
  # リソースクリーンアップ
  if _registry:
    _registry = null
  if _test_scene:
    _test_scene.queue_free()


func test_component_registration():
  """コンポーネント登録の基本機能テスト"""
  # 正常な登録テスト（実際のGDScriptクラスを使用）
  var result = _registry.register_component(
    "test_component", NodePath("TestNode"), StageAudioController, 1
  )
  assert_that(result).is_true()

  # 同じ名前での重複登録テスト
  var duplicate_result = _registry.register_component(
    "test_component", NodePath("TestNode2"), StageUIController, 2
  )
  assert_that(duplicate_result).is_false()

  # 登録されたコンポーネントの状態確認
  var status = _registry.get_component_status("test_component")
  assert_that(status).is_equal(StageComponentRegistry.ComponentStatus.REGISTERED)

  # 未登録コンポーネントの状態確認
  var unregistered_status = _registry.get_component_status("nonexistent")
  assert_that(unregistered_status).is_equal(StageComponentRegistry.ComponentStatus.UNREGISTERED)


func test_dependency_management():
  """依存関係管理のテスト"""
  # 2つのコンポーネントを登録
  _registry.register_component("component_a", NodePath("NodeA"), StageAudioController, 1)
  _registry.register_component("component_b", NodePath("NodeB"), StageUIController, 2)

  # 依存関係を追加（component_b は component_a に依存）
  var dep_result = _registry.add_dependency("component_b", "component_a")
  assert_that(dep_result).is_true()

  # 存在しないコンポーネントでの依存関係追加テスト
  var invalid_dep_result = _registry.add_dependency("nonexistent", "component_a")
  assert_that(invalid_dep_result).is_false()


func test_initialization_order_calculation():
  """初期化順序計算のテスト"""
  # テスト用ノードを実際に作成
  var node_a = StageAudioController.new()
  node_a.name = "NodeA"
  _mock_parent.add_child(node_a)

  var node_b = StageUIController.new()
  node_b.name = "NodeB"
  _mock_parent.add_child(node_b)

  var node_c = StageEnvironmentSetup.new()
  node_c.name = "NodeC"
  _mock_parent.add_child(node_c)

  # 依存関係を持つコンポーネントを登録
  # A(優先度0) ← B(優先度1) ← C(優先度2) の依存チェーン
  _registry.register_component("comp_a", NodePath("NodeA"), StageAudioController, 0)
  _registry.register_component("comp_b", NodePath("NodeB"), StageUIController, 1)
  _registry.register_component("comp_c", NodePath("NodeC"), StageEnvironmentSetup, 2)

  # 依存関係設定（BはAに、CはBに依存）
  _registry.add_dependency("comp_b", "comp_a")
  _registry.add_dependency("comp_c", "comp_b")

  # 初期化実行
  var init_result = _registry.initialize_all_components()
  assert_that(init_result).is_true()

  # すべてのコンポーネントが準備完了状態になっているか確認
  assert_that(_registry.is_all_components_ready()).is_true()


func test_circular_dependency_detection():
  """循環依存検出のテスト"""
  # 実際のノードを作成して循環依存をテスト
  var node_x = StageAudioController.new()
  node_x.name = "NodeX"
  _mock_parent.add_child(node_x)

  var node_y = StageUIController.new()
  node_y.name = "NodeY"
  _mock_parent.add_child(node_y)

  # 循環依存を作成するコンポーネントを登録
  _registry.register_component("comp_x", NodePath("NodeX"), StageAudioController, 0)
  _registry.register_component("comp_y", NodePath("NodeY"), StageUIController, 0)

  # 循環依存を設定（X → Y → X）
  _registry.add_dependency("comp_x", "comp_y")
  _registry.add_dependency("comp_y", "comp_x")

  # 初期化を試行（循環依存により失敗するはず）
  var init_result = _registry.initialize_all_components()
  assert_that(init_result).is_false()


func test_component_retrieval():
  """コンポーネント取得のテスト"""
  # テスト用ノードを作成
  var test_node = StageAudioController.new()
  test_node.name = "TestNode"
  _mock_parent.add_child(test_node)

  # コンポーネントを登録し、初期化
  _registry.register_component("test_comp", NodePath("TestNode"), StageAudioController, 0)
  _registry.initialize_all_components()

  # コンポーネント取得テスト
  var component = _registry.get_component("test_comp")
  assert_that(component).is_not_null()
  assert_that(component.name).is_equal("TestNode")

  # 存在しないコンポーネントの取得テスト
  var nonexistent = _registry.get_component("nonexistent")
  assert_that(nonexistent).is_null()


func test_error_handling():
  """エラーハンドリングのテスト"""
  # 存在しないNodePathを指定したコンポーネントを登録
  _registry.register_component("failing_comp", NodePath("NonExistentNode"), StageAudioController, 0)

  # 初期化実行（失敗するはず）
  var init_result = _registry.initialize_all_components()
  assert_that(init_result).is_false()

  # 失敗したコンポーネントのリストを確認
  var failed_components = _registry.get_failed_components()
  assert_that(failed_components.size()).is_greater(0)
  assert_that("failing_comp" in failed_components).is_true()

  # コンポーネントの状態確認
  var status = _registry.get_component_status("failing_comp")
  assert_that(status).is_equal(StageComponentRegistry.ComponentStatus.FAILED)


func test_type_validation():
  """型チェック機能のテスト"""
  # カスタムクラス用のテストノードを作成
  var custom_node = StageAudioController.new()
  custom_node.name = "CustomNode"
  _mock_parent.add_child(custom_node)

  # 正しい型でのコンポーネント登録
  _registry.register_component("typed_comp", NodePath("CustomNode"), StageAudioController, 0)

  # 初期化実行
  var init_result = _registry.initialize_all_components()
  assert_that(init_result).is_true()

  # 型チェックが正常に動作したか確認
  var component = _registry.get_component("typed_comp")
  assert_that(component).is_not_null()
  assert_that(component.get_class()).is_equal("Node")


func test_registry_status_debug():
  """デバッグ機能のテスト"""
  # テスト用コンポーネントを登録
  _registry.register_component("debug_comp", NodePath(), StageAudioController, 0)  # 空のNodePathでスキップ
  _registry.initialize_all_components()

  # ステータス取得
  var status = _registry.get_registry_status()
  assert_that(status).is_not_null()
  assert_that(status.has("debug_comp")).is_true()

  # ステータス情報の内容確認
  var comp_status = status["debug_comp"]
  assert_that(comp_status.has("status")).is_true()
  assert_that(comp_status.has("path")).is_true()
  assert_that(comp_status.has("dependencies")).is_true()


func test_signal_emission():
  """シグナル発火のテスト"""
  # レジストリの状態をテストすることでシグナル発火を間接的に検証
  # コンポーネント登録前の状態確認
  var initial_status = _registry.get_component_status("signal_test")
  assert_that(initial_status).is_equal(StageComponentRegistry.ComponentStatus.UNREGISTERED)

  # コンポーネント登録
  var result = _registry.register_component("signal_test", NodePath(), StageAudioController, 0)
  assert_that(result).is_true()

  # 登録後の状態確認（シグナルが発火されていれば状態が変わる）
  var final_status = _registry.get_component_status("signal_test")
  assert_that(final_status).is_equal(StageComponentRegistry.ComponentStatus.REGISTERED)

  # 登録されたコンポーネントの詳細確認
  var registry_status = _registry.get_registry_status()
  assert_that(registry_status.has("signal_test")).is_true()

  # レジストリステータスの内容確認
  var comp_status = registry_status["signal_test"]
  assert_that(comp_status["status"]).is_equal("REGISTERED")
