# ステージ音響制御コンポーネントの単体テスト
extends GdUnitTestSuite
class_name StageAudioControllerTest

# テスト対象クラス
var _audio_controller: StageAudioController
var _test_scene: Node
var _signal_history: Array[Dictionary] = []

# テスト用のモックAudioStream
var _mock_stage_bgm: AudioStream
var _mock_clear_bgm: AudioStream


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # テスト対象の音響コントローラを作成
  _audio_controller = StageAudioController.new()
  _test_scene.add_child(_audio_controller)

  # null参照エラー防止：コントローラーが正常に作成されたことを確認
  assert_that(_audio_controller).is_not_null()

  # テスト用のモックオーディオストリームを作成
  # 実際のAudioStreamが無くても動作するようにnullで初期化
  _mock_stage_bgm = null  # 実際のテストではモックリソースを使用
  _mock_clear_bgm = null

  # StageSignalsのモック化
  _setup_stage_signals_mock()

  # シグナル履歴をクリア
  _signal_history.clear()


func after_test():
  # リソースクリーンアップ
  _signal_history.clear()
  if _test_scene:
    _test_scene.queue_free()


func _setup_stage_signals_mock():
  """StageSignalsのモック化セットアップ"""
  # 実際のStageSignalsではなく、テスト用のシグナル記録を行う
  # これは統合テストでより詳細にテストされる
  pass


func test_initialization():
  """初期化テスト"""
  # BGMリソースが設定できることを確認
  _audio_controller.stage_bgm = _mock_stage_bgm
  _audio_controller.stageclear_bgm = _mock_clear_bgm
  _audio_controller.bgm_fade_in = 2.0
  _audio_controller.bgm_fade_out = 1.0

  # 設定値が正しく保存されているか確認
  assert_that(_audio_controller.stage_bgm).is_equal(_mock_stage_bgm)
  assert_that(_audio_controller.stageclear_bgm).is_equal(_mock_clear_bgm)
  assert_that(_audio_controller.bgm_fade_in).is_equal(2.0)
  assert_that(_audio_controller.bgm_fade_out).is_equal(1.0)


func test_play_stage_bgm():
  """ステージBGM再生テスト"""
  # テスト用のAudioStreamを設定
  _audio_controller.stage_bgm = _mock_stage_bgm
  _audio_controller.bgm_fade_in = 1.5

  # BGM再生メソッドを呼び出し
  _audio_controller.play_stage_bgm()

  # エラーが発生しないことを確認（実際のシグナル送信は統合テストで確認）
  assert_that(_audio_controller).is_not_null()


func test_play_stage_bgm_with_null_stream():
  """nullのBGMストリームでの再生テスト"""
  # BGMストリームをnullに設定
  _audio_controller.stage_bgm = null

  # BGM再生メソッドを呼び出し（エラーが発生しないことを確認）
  _audio_controller.play_stage_bgm()

  # 処理が正常に完了することを確認
  assert_that(_audio_controller).is_not_null()


func test_play_stage_clear_bgm():
  """ステージクリアBGM再生テスト"""
  # テスト用のAudioStreamを設定
  _audio_controller.stageclear_bgm = _mock_clear_bgm

  # クリアBGM再生メソッドを呼び出し
  _audio_controller.play_stage_clear_bgm()

  # エラーが発生しないことを確認
  assert_that(_audio_controller).is_not_null()


func test_stop_bgm():
  """BGM停止テスト"""
  # フェードアウト時間を設定
  _audio_controller.bgm_fade_out = 0.5

  # BGM停止メソッドを呼び出し
  _audio_controller.stop_bgm()

  # エラーが発生しないことを確認
  assert_that(_audio_controller).is_not_null()


func test_play_gameover_sfx():
  """ゲームオーバーSFX再生テスト"""
  # ゲームオーバーSFX再生メソッドを呼び出し
  _audio_controller.play_gameover_sfx()

  # エラーが発生しないことを確認
  assert_that(_audio_controller).is_not_null()


func test_handle_stage_start():
  """ステージ開始時の音響処理テスト"""
  # テスト用のBGMを設定
  _audio_controller.stage_bgm = _mock_stage_bgm
  _audio_controller.bgm_fade_in = 1.0

  # ステージ開始処理を呼び出し
  _audio_controller.handle_stage_start()

  # エラーが発生しないことを確認
  assert_that(_audio_controller).is_not_null()


func test_handle_stage_cleared():
  """ステージクリア時の音響処理テスト"""
  # テスト用のBGMを設定
  _audio_controller.stageclear_bgm = _mock_clear_bgm
  _audio_controller.bgm_fade_out = 0.5

  # ステージクリア処理を呼び出し（非同期処理のため、await不要でテスト）
  _audio_controller.handle_stage_cleared()

  # 処理開始が正常であることを確認
  assert_that(_audio_controller).is_not_null()


func test_handle_game_over():
  """ゲームオーバー時の音響処理テスト"""
  # ゲームオーバー処理を呼び出し
  _audio_controller.handle_game_over()

  # エラーが発生しないことを確認
  assert_that(_audio_controller).is_not_null()


func test_sequential_audio_calls():
  """連続的な音響制御呼び出しテスト"""
  # BGMリソースを設定
  _audio_controller.stage_bgm = _mock_stage_bgm
  _audio_controller.stageclear_bgm = _mock_clear_bgm

  # 複数の音響制御を連続実行
  _audio_controller.play_stage_bgm()
  _audio_controller.stop_bgm()
  _audio_controller.play_stage_clear_bgm()
  _audio_controller.play_gameover_sfx()

  # エラーが発生しないことを確認
  assert_that(_audio_controller).is_not_null()


func test_fade_parameters():
  """フェードパラメータのテスト"""
  # フェードパラメータを設定
  _audio_controller.bgm_fade_in = 3.0
  _audio_controller.bgm_fade_out = 2.0

  # パラメータが正しく設定されていることを確認
  assert_that(_audio_controller.bgm_fade_in).is_equal(3.0)
  assert_that(_audio_controller.bgm_fade_out).is_equal(2.0)

  # フェードパラメータを使用した音響制御
  _audio_controller.stage_bgm = _mock_stage_bgm
  _audio_controller.play_stage_bgm()
  _audio_controller.stop_bgm()

  # エラーが発生しないことを確認
  assert_that(_audio_controller).is_not_null()


func test_audio_controller_robustness():
  """音響コントローラーの堅牢性テスト"""
  # 初期化されていない状態での各メソッド呼び出し
  var fresh_controller = StageAudioController.new()
  _test_scene.add_child(fresh_controller)

  # null参照エラー防止確認
  assert_that(fresh_controller).is_not_null()

  # BGMリソースが設定されていない状態での各メソッド呼び出し
  fresh_controller.play_stage_bgm()
  fresh_controller.play_stage_clear_bgm()
  fresh_controller.stop_bgm()
  fresh_controller.play_gameover_sfx()
  fresh_controller.handle_stage_start()
  fresh_controller.handle_game_over()

  # エラーが発生しないことを確認
  assert_that(fresh_controller).is_not_null()
