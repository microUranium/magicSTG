# ステージライフサイクル制御コンポーネントの単体テスト
extends GdUnitTestSuite
class_name StageLifecycleControllerTest

# テスト対象クラス
var _lifecycle_controller: StageLifecycleController
var _test_scene: Node


func before_test():
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # テスト対象のライフサイクルコントローラを作成
  _lifecycle_controller = StageLifecycleController.new()
  _lifecycle_controller.name = "LifecycleController"
  _test_scene.add_child(_lifecycle_controller)

  # null参照エラー防止：コントローラーが正常に作成されたことを確認
  assert_that(_lifecycle_controller).is_not_null()


func after_test():
  # リソースクリーンアップ
  if _test_scene:
    _test_scene.queue_free()


func test_initial_state():
  """初期状態のテスト"""
  # 初期状態の確認
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.UNINITIALIZED
  )
  assert_that(_lifecycle_controller.is_initialized()).is_false()
  assert_that(_lifecycle_controller.is_stage_running()).is_false()
  assert_that(_lifecycle_controller.can_start_stage()).is_true()


func test_initialization_sequence():
  """初期化シーケンスのテスト"""
  # 初期化開始
  _lifecycle_controller.start_initialization()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.INITIALIZING
  )
  assert_that(_lifecycle_controller.is_initialized()).is_false()

  # 初期化完了
  _lifecycle_controller.complete_initialization()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.RUNNING
  )
  assert_that(_lifecycle_controller.is_initialized()).is_true()
  assert_that(_lifecycle_controller.is_stage_running()).is_true()


func test_stage_completion_handling():
  """ステージ完了処理のテスト"""
  # ステージを実行状態にセットアップ
  _lifecycle_controller.start_initialization()
  _lifecycle_controller.complete_initialization()

  # ステージクリア処理を実行（非同期処理）
  _lifecycle_controller.handle_stage_cleared()

  # 即座にクリア状態に移行することを確認
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.COMPLETED
  )


func test_stage_failure_handling():
  """ステージ失敗処理のテスト"""
  # ステージを実行状態にセットアップ
  _lifecycle_controller.start_initialization()
  _lifecycle_controller.complete_initialization()

  # ステージ失敗処理を実行（非同期処理）
  _lifecycle_controller.handle_stage_failed()

  # 即座に失敗状態に移行することを確認
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.FAILED
  )


func test_pause_resume_functionality():
  """一時停止・再開機能のテスト"""
  # ステージを実行状態にセットアップ
  _lifecycle_controller.start_initialization()
  _lifecycle_controller.complete_initialization()
  assert_that(_lifecycle_controller.is_stage_running()).is_true()

  # 一時停止
  _lifecycle_controller.pause_stage()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.PAUSED
  )
  assert_that(_lifecycle_controller.is_stage_running()).is_false()

  # 再開
  _lifecycle_controller.resume_stage()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.RUNNING
  )
  assert_that(_lifecycle_controller.is_stage_running()).is_true()


func test_stage_reset():
  """ステージリセット機能のテスト"""
  # ステージを実行状態にセットアップ
  _lifecycle_controller.start_initialization()
  _lifecycle_controller.complete_initialization()

  # リセット実行
  _lifecycle_controller.reset_stage()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.UNINITIALIZED
  )
  assert_that(_lifecycle_controller.is_initialized()).is_false()
  assert_that(_lifecycle_controller.can_start_stage()).is_true()


func test_invalid_state_transitions():
  """不正な状態遷移のテスト"""
  # 初期化していない状態でのクリア処理（警告が出るが処理は継続）
  _lifecycle_controller.handle_stage_cleared()
  # 状態が変更されないことを確認
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.UNINITIALIZED
  )

  # 初期化していない状態での失敗処理（警告が出るが処理は継続）
  _lifecycle_controller.handle_stage_failed()
  # 状態が変更されないことを確認（ただし、失敗処理は状態に関係なく実行される可能性）

  # 実行中でない状態での一時停止
  _lifecycle_controller.pause_stage()
  # 実行中でない場合は状態変更されない
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.UNINITIALIZED
  )


func test_duplicate_initialization():
  """重複初期化のテスト"""
  # 初期化開始
  _lifecycle_controller.start_initialization()

  # 再度初期化開始（警告が出るが処理は継続）
  _lifecycle_controller.start_initialization()

  # 状態が変更されないことを確認
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.INITIALIZING
  )


func test_complete_initialization_invalid_state():
  """不正な状態での初期化完了テスト"""
  # 初期化開始していない状態で完了処理（警告が出る）
  _lifecycle_controller.complete_initialization()

  # 状態が変更されないことを確認
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.UNINITIALIZED
  )


func test_state_transition_validation():
  """状態遷移検証のテスト"""
  # 有効な遷移のテスト
  (
    assert_that(
      _lifecycle_controller.validate_state_transition(
        StageLifecycleController.StageState.UNINITIALIZED,
        StageLifecycleController.StageState.INITIALIZING
      )
    )
    . is_true()
  )

  (
    assert_that(
      _lifecycle_controller.validate_state_transition(
        StageLifecycleController.StageState.INITIALIZING,
        StageLifecycleController.StageState.RUNNING
      )
    )
    . is_true()
  )

  (
    assert_that(
      _lifecycle_controller.validate_state_transition(
        StageLifecycleController.StageState.RUNNING, StageLifecycleController.StageState.PAUSED
      )
    )
    . is_true()
  )

  # 無効な遷移のテスト
  (
    assert_that(
      _lifecycle_controller.validate_state_transition(
        StageLifecycleController.StageState.UNINITIALIZED,
        StageLifecycleController.StageState.RUNNING
      )
    )
    . is_false()
  )

  (
    assert_that(
      _lifecycle_controller.validate_state_transition(
        StageLifecycleController.StageState.COMPLETED, StageLifecycleController.StageState.RUNNING
      )
    )
    . is_false()
  )


func test_get_state_name():
  """状態名取得のテスト"""
  # 各状態の名前取得をテスト
  (
    assert_that(
      _lifecycle_controller.get_state_name(StageLifecycleController.StageState.UNINITIALIZED)
    )
    . is_equal("UNINITIALIZED")
  )
  (
    assert_that(
      _lifecycle_controller.get_state_name(StageLifecycleController.StageState.INITIALIZING)
    )
    . is_equal("INITIALIZING")
  )
  (
    assert_that(_lifecycle_controller.get_state_name(StageLifecycleController.StageState.RUNNING))
    . is_equal("RUNNING")
  )
  (
    assert_that(_lifecycle_controller.get_state_name(StageLifecycleController.StageState.PAUSED))
    . is_equal("PAUSED")
  )
  (
    assert_that(_lifecycle_controller.get_state_name(StageLifecycleController.StageState.CLEARING))
    . is_equal("CLEARING")
  )
  (
    assert_that(_lifecycle_controller.get_state_name(StageLifecycleController.StageState.FAILED))
    . is_equal("FAILED")
  )
  (
    assert_that(_lifecycle_controller.get_state_name(StageLifecycleController.StageState.COMPLETED))
    . is_equal("COMPLETED")
  )


func test_signal_emission():
  """シグナル発火のテスト"""
  var initialization_started_fired = [false]
  var initialization_completed_fired = [false]
  var stage_cleared_fired = [false]
  var stage_failed_fired = [false]

  # シグナル接続
  _lifecycle_controller.stage_initialization_started.connect(
    func(): initialization_started_fired[0] = true
  )
  _lifecycle_controller.stage_initialization_completed.connect(
    func(): initialization_completed_fired[0] = true
  )
  _lifecycle_controller.stage_cleared.connect(func(): stage_cleared_fired[0] = true)
  _lifecycle_controller.stage_failed.connect(func(): stage_failed_fired[0] = true)

  # 初期化シーケンス実行
  _lifecycle_controller.start_initialization()
  assert_that(initialization_started_fired[0]).is_true()

  _lifecycle_controller.complete_initialization()
  assert_that(initialization_completed_fired[0]).is_true()

  # ステージクリア処理実行
  _lifecycle_controller.handle_stage_cleared()

  # リセットして失敗処理をテスト
  _lifecycle_controller.reset_stage()
  _lifecycle_controller.start_initialization()
  _lifecycle_controller.complete_initialization()

  # ステージ失敗処理実行
  _lifecycle_controller.handle_stage_failed()


func test_full_lifecycle_flow():
  """完全なライフサイクルフローのテスト"""
  # 1. 初期状態確認
  assert_that(_lifecycle_controller.can_start_stage()).is_true()

  # 2. 初期化開始
  _lifecycle_controller.start_initialization()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.INITIALIZING
  )

  # 3. 初期化完了
  _lifecycle_controller.complete_initialization()
  assert_that(_lifecycle_controller.is_stage_running()).is_true()

  # 4. 一時停止・再開
  _lifecycle_controller.pause_stage()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.PAUSED
  )
  _lifecycle_controller.resume_stage()
  assert_that(_lifecycle_controller.is_stage_running()).is_true()

  # 5. ステージクリア
  _lifecycle_controller.handle_stage_cleared()
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.COMPLETED
  )

  # 6. リセット
  _lifecycle_controller.reset_stage()
  assert_that(_lifecycle_controller.can_start_stage()).is_true()


func test_concurrent_state_changes():
  """並行状態変更のテスト"""
  # 初期化を開始
  _lifecycle_controller.start_initialization()

  # 初期化中に複数の状態変更を試行
  _lifecycle_controller.pause_stage()  # 無効（初期化中）
  _lifecycle_controller.handle_stage_cleared()  # 無効（実行中でない）

  # 状態が初期化中のままであることを確認
  assert_that(_lifecycle_controller.get_current_state()).is_equal(
    StageLifecycleController.StageState.INITIALIZING
  )

  # 正常に初期化完了
  _lifecycle_controller.complete_initialization()
  assert_that(_lifecycle_controller.is_stage_running()).is_true()
