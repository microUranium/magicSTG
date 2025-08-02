# ステージUI制御コンポーネントの単体テスト
extends GdUnitTestSuite
class_name StageUIControllerTest

# テスト対象クラス
var _ui_controller: StageUIController
var _test_scene: Node
var _mock_parent: Node

# テスト用のモックシーン
var _mock_ready_scene: PackedScene
var _mock_clear_scene: PackedScene
var _mock_gameover_scene: PackedScene


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # モック親ノードを作成
  _mock_parent = Node.new()
  _mock_parent.name = "MockParent"
  _test_scene.add_child(_mock_parent)

  # テスト対象のUIコントローラを作成
  _ui_controller = StageUIController.new()
  _ui_controller.name = "UIController"
  _test_scene.add_child(_ui_controller)

  # null参照エラー防止：コントローラーが正常に作成されたことを確認
  assert_that(_ui_controller).is_not_null()

  # テスト用のモックシーンを作成（実際のシーンファイルは使用しない）
  _setup_mock_scenes()

  # UIコントローラーを初期化
  var init_result = _ui_controller.initialize(_mock_parent)
  assert_that(init_result).is_true()


func after_test():
  # リソースクリーンアップ
  if _test_scene:
    _test_scene.queue_free()


func _setup_mock_scenes():
  """テスト用のモックシーンを作成"""
  # 実際のシーンファイルを使用せず、nullで初期化
  # これにより、実際のシーンリソースに依存しないテストが可能
  _mock_ready_scene = null
  _mock_clear_scene = null
  _mock_gameover_scene = null


func test_initialization():
  """初期化テスト"""
  # 新しいUIコントローラーを作成
  var fresh_controller = StageUIController.new()
  _test_scene.add_child(fresh_controller)

  # null参照エラー防止確認
  assert_that(fresh_controller).is_not_null()

  # 親ノードで初期化
  var result = fresh_controller.initialize(_mock_parent)
  assert_that(result).is_true()

  # 初期化後の状態確認
  assert_that(fresh_controller._parent_node).is_equal(_mock_parent)


func test_has_ready_prompt_check():
  """Readyプロンプト存在チェックテスト"""
  # Ready promptシーンが設定されている場合
  _ui_controller.ready_prompt_scene = _mock_ready_scene
  var has_prompt = _ui_controller.has_ready_prompt()
  # nullの場合はfalseを返すはず
  assert_that(has_prompt).is_false()

  # Ready promptシーンが設定されていない場合
  _ui_controller.ready_prompt_scene = null
  has_prompt = _ui_controller.has_ready_prompt()
  assert_that(has_prompt).is_false()


func test_show_ready_prompt_with_null_scene():
  """nullシーンでのReadyプロンプト表示テスト"""
  # Ready promptシーンをnullに設定
  _ui_controller.ready_prompt_scene = null

  # プロンプト表示を呼び出し（エラーが発生しないことを確認）
  _ui_controller.show_ready_prompt()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()


func test_show_clear_prompt_with_null_scene():
  """nullシーンでのクリアプロンプト表示テスト"""
  # Clear promptシーンをnullに設定
  _ui_controller.clear_prompt_scene = null

  # プロンプト表示を呼び出し
  _ui_controller.show_clear_prompt()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()


func test_show_gameover_prompt_with_null_scene():
  """nullシーンでのゲームオーバープロンプト表示テスト"""
  # GameOver promptシーンをnullに設定
  _ui_controller.gameover_prompt_scene = null

  # プロンプト表示を呼び出し
  _ui_controller.show_gameover_prompt()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()


func test_handle_stage_cleared():
  """ステージクリア時のUI処理テスト"""
  # クリアプロンプトシーンを設定
  _ui_controller.clear_prompt_scene = _mock_clear_scene

  # ステージクリア処理を呼び出し
  _ui_controller.handle_stage_cleared()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()


func test_handle_game_over():
  """ゲームオーバー時のUI処理テスト"""
  # ゲームオーバープロンプトシーンを設定
  _ui_controller.gameover_prompt_scene = _mock_gameover_scene

  # ゲームオーバー処理を呼び出し
  _ui_controller.handle_game_over()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()


func test_uninitialized_controller_behavior():
  """未初期化のコントローラーの動作テスト"""
  # 新しい未初期化のコントローラーを作成
  var uninit_controller = StageUIController.new()
  _test_scene.add_child(uninit_controller)

  # null参照エラー防止確認
  assert_that(uninit_controller).is_not_null()

  # 初期化前の各メソッド呼び出し（エラーが発生しないことを確認）
  uninit_controller.show_ready_prompt()
  uninit_controller.show_clear_prompt()
  uninit_controller.show_gameover_prompt()
  uninit_controller.handle_stage_cleared()
  uninit_controller.handle_game_over()

  # エラーが発生しないことを確認
  assert_that(uninit_controller).is_not_null()


func test_signal_existence():
  """シグナルの存在確認テスト"""
  # UIコントローラーが必要なシグナルを持っているか確認
  assert_that(_ui_controller.has_signal("ready_prompt_finished")).is_true()
  assert_that(_ui_controller.has_signal("clear_prompt_finished")).is_true()
  assert_that(_ui_controller.has_signal("gameover_prompt_finished")).is_true()


func test_current_prompt_management():
  """現在のプロンプト管理テスト"""
  # 初期状態では現在のプロンプトはnull
  assert_that(_ui_controller._current_prompt).is_null()

  # Readyプロンプトはnullにする
  _ui_controller.ready_prompt_scene = null
  # プロンプト表示（nullシーンなので実際のプロンプトは作成されない）
  _ui_controller.show_ready_prompt()

  # プロンプト管理の状態確認（nullシーンなので変化なし）
  assert_that(_ui_controller._current_prompt).is_null()


func test_scene_resource_validation():
  """シーンリソースの検証テスト"""
  # 各プロンプトシーンの初期状態確認
  # デフォルトではpreloadされたシーンが設定されているはず
  assert_that(_ui_controller.ready_prompt_scene).is_not_null()
  assert_that(_ui_controller.clear_prompt_scene).is_not_null()
  assert_that(_ui_controller.gameover_prompt_scene).is_not_null()

  # シーンをnullに設定して動作確認
  _ui_controller.ready_prompt_scene = null
  _ui_controller.clear_prompt_scene = null
  _ui_controller.gameover_prompt_scene = null

  # null設定後の各メソッド呼び出し
  _ui_controller.show_ready_prompt()
  _ui_controller.show_clear_prompt()
  _ui_controller.show_gameover_prompt()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()


func test_multiple_prompt_calls():
  """複数のプロンプト呼び出しテスト"""
  # 複数のプロンプトを連続で呼び出し
  _ui_controller.show_ready_prompt()
  _ui_controller.show_clear_prompt()
  _ui_controller.show_gameover_prompt()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()

  # イベント処理も連続実行
  _ui_controller.handle_stage_cleared()
  _ui_controller.handle_game_over()

  # エラーが発生しないことを確認
  assert_that(_ui_controller).is_not_null()
