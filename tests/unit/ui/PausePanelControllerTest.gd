# PausePanelControllerの単体テスト
extends GdUnitTestSuite
class_name PausePanelControllerTest

# テスト対象のシーン
const PAUSE_PANEL_SCENE := "res://scenes/ui/pause_panel.tscn"

var _controller: PausePanelController
var _test_scene: Node


func before_test() -> void:
  # テスト用のシーンセットアップ
  _test_scene = Node.new()
  _test_scene.name = "TestScene"
  add_child(_test_scene)

  # ポーズパネルシーンをインスタンス化
  var scene = load(PAUSE_PANEL_SCENE).instantiate()
  _controller = scene
  _test_scene.add_child(_controller)

  # 1フレーム待機してノードが完全に初期化されるのを待つ
  await await_idle_frame()


func after_test() -> void:
  # リソースクリーンアップ
  if _test_scene:
    _test_scene.queue_free()


#---------------------------------------------------------------------
# 1. 初期化テスト
#---------------------------------------------------------------------


func test_initial_state() -> void:
  """初期状態の検証"""
  # パネルが非表示であること
  assert_that(_controller.visible).is_false()

  # ポーズ状態が無効
  assert_that(_controller.is_paused()).is_false()

  # process_modeがPROCESS_MODE_ALWAYSであること
  assert_that(_controller.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)

  # 内部状態の確認
  assert_that(_controller._is_paused).is_false()
  assert_that(_controller._can_pause).is_false()
  assert_that(_controller._has_been_shown).is_false()
  assert_that(_controller._quit_button_confirmed).is_false()


func test_ready_initialization() -> void:
  """_ready()での初期化確認"""
  # プロセスモードが設定されている
  assert_that(_controller.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)

  # パネルが非表示
  assert_that(_controller.visible).is_false()

  # _has_been_shownがfalse（バグ修正の検証：初期化時はfalseであるべき）
  assert_that(_controller._has_been_shown).is_false()


#---------------------------------------------------------------------
# 2. パネル表示/非表示テスト
#---------------------------------------------------------------------


func test_show_panel() -> void:
  """パネル表示の検証"""
  # パネルを表示
  _controller.show_panel()

  # パネルが表示されること
  assert_that(_controller.visible).is_true()

  # 内部状態の確認
  assert_that(_controller._is_paused).is_true()
  assert_that(_controller._has_been_shown).is_true()

  # DarkOverlayが表示されること
  var dark_overlay = _controller.get_node("DarkOverlay")
  assert_that(dark_overlay.visible).is_true()


func test_hide_panel_after_show() -> void:
  """表示後の非表示検証"""
  # まず表示
  _controller.show_panel()

  # 非表示にする
  _controller.hide_panel()

  # パネルが非表示になること
  assert_that(_controller.visible).is_false()
  assert_that(_controller._is_paused).is_false()

  # DarkOverlayが非表示になること
  var dark_overlay = _controller.get_node("DarkOverlay")
  assert_that(dark_overlay.visible).is_false()


func test_hide_panel_without_show() -> void:
  """未表示時の非表示検証（初期化時の状態）"""
  # 新しいコントローラーを作成（_has_been_shown = false）
  var fresh_scene = load(PAUSE_PANEL_SCENE).instantiate()
  var fresh_controller: PausePanelController = fresh_scene
  _test_scene.add_child(fresh_controller)

  await await_idle_frame()

  # hide_panel()を呼び出す
  fresh_controller.hide_panel()

  # _has_been_shownがfalseのままであること
  assert_that(fresh_controller._has_been_shown).is_false()

  fresh_controller.queue_free()


func test_has_been_shown_flag_persistence() -> void:
  """_has_been_shownフラグの永続性テスト"""
  # 初期状態: false
  assert_that(_controller._has_been_shown).is_false()

  # 表示後: true
  _controller.show_panel()
  assert_that(_controller._has_been_shown).is_true()

  # 非表示後もtrue（一度表示されたらフラグは維持される）
  _controller.hide_panel()
  assert_that(_controller._has_been_shown).is_true()

  # 再度表示してもtrue
  _controller.show_panel()
  assert_that(_controller._has_been_shown).is_true()


#---------------------------------------------------------------------
# 3. ポーズ有効化/無効化テスト
#---------------------------------------------------------------------


func test_enable_pause() -> void:
  """ポーズ有効化"""
  _controller.enable_pause()

  assert_that(_controller._can_pause).is_true()


func test_disable_pause_when_not_paused() -> void:
  """非ポーズ時の無効化"""
  _controller.enable_pause()
  _controller.disable_pause()

  assert_that(_controller._can_pause).is_false()


func test_disable_pause_when_paused() -> void:
  """ポーズ中の無効化 - 強制的にポーズが解除されること"""
  _controller.enable_pause()
  _controller.show_panel()

  # ポーズ中であることを確認
  assert_that(_controller._is_paused).is_true()

  # 無効化
  _controller.disable_pause()

  # 強制的にポーズが解除されること
  assert_that(_controller._can_pause).is_false()
  assert_that(_controller._is_paused).is_false()
  assert_that(_controller.visible).is_false()


#---------------------------------------------------------------------
# 4. ポーズ切り替えテスト
#---------------------------------------------------------------------


func test_toggle_pause_when_disabled() -> void:
  """ポーズ無効時の切り替え - 何も起こらないこと"""
  # 初期状態
  var initial_paused = _controller._is_paused

  # ポーズ無効の状態でトグル
  _controller.toggle_pause()

  # 状態が変わらない
  assert_that(_controller._is_paused).is_equal(initial_paused)


func test_is_paused_getter() -> void:
  """is_paused()ゲッターのテスト"""
  # 初期状態: false
  assert_that(_controller.is_paused()).is_false()

  # パネル表示後: true
  _controller.enable_pause()
  _controller.show_panel()
  assert_that(_controller.is_paused()).is_true()

  # パネル非表示後: false
  _controller.hide_panel()
  assert_that(_controller.is_paused()).is_false()


#---------------------------------------------------------------------
# 5. ESCキー入力テスト
#---------------------------------------------------------------------


func test_esc_key_when_pause_disabled() -> void:
  """ポーズ無効時のESCキー - 何も起こらないこと"""
  var initial_state = _controller._is_paused

  # ESCキーイベントを作成
  var event = InputEventKey.new()
  event.keycode = KEY_ESCAPE
  event.pressed = true
  event.echo = false

  # イベントを送信
  _controller._unhandled_input(event)

  # 状態が変わらない
  assert_that(_controller._is_paused).is_equal(initial_state)


func test_esc_key_echo_ignored() -> void:
  """エコーイベントの無視"""
  _controller.enable_pause()
  var initial_state = _controller._is_paused

  # エコーイベントを作成
  var event = InputEventKey.new()
  event.keycode = KEY_ESCAPE
  event.pressed = true
  event.echo = true  # エコー

  # イベントを送信
  _controller._unhandled_input(event)

  # 状態が変わらない
  assert_that(_controller._is_paused).is_equal(initial_state)


func test_esc_key_release_ignored() -> void:
  """ESCキーリリースイベントの無視"""
  _controller.enable_pause()
  var initial_state = _controller._is_paused

  # リリースイベントを作成
  var event = InputEventKey.new()
  event.keycode = KEY_ESCAPE
  event.pressed = false  # リリース
  event.echo = false

  # イベントを送信
  _controller._unhandled_input(event)

  # 状態が変わらない
  assert_that(_controller._is_paused).is_equal(initial_state)


#---------------------------------------------------------------------
# 6. ボタンクリックテスト
#---------------------------------------------------------------------


func test_quit_button_first_click() -> void:
  """「あきらめる」初回クリック - 確認状態に移行"""
  _controller.enable_pause()
  _controller.show_panel()

  # 初回クリック
  _controller._on_quit_clicked()

  # 確認状態に移行
  assert_that(_controller._quit_button_confirmed).is_true()

  # テキストと色の確認
  var quit_label = _controller.get_node("VBoxContainer/Escape/Label")
  assert_that(quit_label.text).is_equal("あきらめる？")
  assert_that(quit_label.get_theme_color("font_color")).is_equal(Color(1.0, 0.0, 0.0, 1.0))


func test_quit_button_state_transitions() -> void:
  """「あきらめる」ボタンの状態遷移テスト"""
  _controller.enable_pause()
  _controller.show_panel()

  # 初期状態: 未確認
  assert_that(_controller._quit_button_confirmed).is_false()

  # 初回クリック: 確認状態
  _controller._on_quit_clicked()
  assert_that(_controller._quit_button_confirmed).is_true()

  # ホバー解除: 未確認に戻る
  _controller._on_quit_button_hover_end()
  assert_that(_controller._quit_button_confirmed).is_false()


#---------------------------------------------------------------------
# 7. ホバーイベントテスト
#---------------------------------------------------------------------


func test_button_hover_scale_animation() -> void:
  """ホバー時のスケールアニメーション"""
  _controller.enable_pause()
  _controller.show_panel()

  var back_label = _controller.get_node("VBoxContainer/Back/Label")
  var initial_scale = back_label.scale

  # ホバー開始
  _controller._on_button_hover_start(back_label, null)

  # Tweenアニメーションの完了を待つ
  await await_millis(200)

  # スケールが1.1倍になること
  assert_that(back_label.scale.x).is_greater_equal(1.05)  # アニメーション途中でも許容
  assert_that(back_label.scale.y).is_greater_equal(1.05)


func test_button_hover_end_scale_restoration() -> void:
  """ホバー解除時のスケール復元"""
  _controller.enable_pause()
  _controller.show_panel()

  var back_label = _controller.get_node("VBoxContainer/Back/Label")

  # まずホバー開始
  _controller._on_button_hover_start(back_label, null)
  await await_millis(200)

  # ホバー解除
  _controller._on_button_hover_end(back_label, null)
  await await_millis(200)

  # スケールが1.0倍に戻る（近似値で確認）
  assert_that(back_label.scale.x).is_less_equal(1.05)
  assert_that(back_label.scale.y).is_less_equal(1.05)


func test_quit_button_hover_end_cancels_confirmation() -> void:
  """ホバー解除で確認キャンセル"""
  _controller.enable_pause()
  _controller.show_panel()

  # 確認状態に移行
  _controller._on_quit_clicked()
  assert_that(_controller._quit_button_confirmed).is_true()

  # ホバー解除
  _controller._on_quit_button_hover_end()

  # 確認状態がリセット
  assert_that(_controller._quit_button_confirmed).is_false()

  # テキストと色が元に戻る
  var quit_label = _controller.get_node("VBoxContainer/Escape/Label")
  assert_that(quit_label.text).is_equal("あきらめる")

  # 色は近似値で確認（浮動小数点の誤差を考慮）
  var actual_color = quit_label.get_theme_color("font_color")
  assert_that(actual_color.r).is_between(0.96, 0.98)
  assert_that(actual_color.g).is_between(0.25, 0.26)
  assert_that(actual_color.b).is_between(0.46, 0.47)


#---------------------------------------------------------------------
# 8. 確認状態リセットテスト
#---------------------------------------------------------------------


func test_hide_panel_resets_quit_confirmation() -> void:
  """パネル非表示で確認リセット"""
  _controller.enable_pause()
  _controller.show_panel()

  # 確認状態に移行
  _controller._on_quit_clicked()
  assert_that(_controller._quit_button_confirmed).is_true()

  # パネルを非表示
  _controller.hide_panel()

  # 確認状態がリセット
  assert_that(_controller._quit_button_confirmed).is_false()


func test_update_quit_button_state() -> void:
  """_update_quit_button_state()メソッドのテスト"""
  _controller.enable_pause()
  _controller.show_panel()

  var quit_label = _controller.get_node("VBoxContainer/Escape/Label")

  # 通常状態
  _controller._quit_button_confirmed = false
  _controller._update_quit_button_state()
  assert_that(quit_label.text).is_equal("あきらめる")

  # 確認状態
  _controller._quit_button_confirmed = true
  _controller._update_quit_button_state()
  assert_that(quit_label.text).is_equal("あきらめる？")
  assert_that(quit_label.get_theme_color("font_color")).is_equal(Color(1.0, 0.0, 0.0, 1.0))


#---------------------------------------------------------------------
# 9. 統合シナリオテスト
#---------------------------------------------------------------------


func test_full_pause_resume_flow() -> void:
  """完全なポーズ/再開フロー"""
  # 1. ポーズ有効化
  _controller.enable_pause()
  assert_that(_controller._can_pause).is_true()

  # 2. パネル表示
  _controller.show_panel()
  assert_that(_controller.is_paused()).is_true()
  assert_that(_controller._has_been_shown).is_true()

  # 3. パネル非表示
  _controller.hide_panel()
  assert_that(_controller.is_paused()).is_false()

  # 4. 再度表示
  _controller.show_panel()
  assert_that(_controller.is_paused()).is_true()

  # 5. ポーズ無効化（強制解除）
  _controller.disable_pause()
  assert_that(_controller.is_paused()).is_false()
  assert_that(_controller._can_pause).is_false()


func test_quit_confirmation_flow() -> void:
  """あきらめるボタンの確認フロー"""
  _controller.enable_pause()
  _controller.show_panel()

  # 1. 初回クリック → 確認状態
  _controller._on_quit_clicked()
  assert_that(_controller._quit_button_confirmed).is_true()

  # 2. ホバー解除 → キャンセル
  _controller._on_quit_button_hover_end()
  assert_that(_controller._quit_button_confirmed).is_false()

  # 3. 再度クリック → 確認状態
  _controller._on_quit_clicked()
  assert_that(_controller._quit_button_confirmed).is_true()

  # 4. 2回目クリック → 確認状態のまま（シグナル発火は統合テストで確認）
  _controller._on_quit_clicked()
  # 状態は維持される（quit_requestedシグナルが発火するがこのテストでは確認しない）
  assert_that(_controller._quit_button_confirmed).is_true()


func test_multiple_show_hide_cycles() -> void:
  """複数回の表示/非表示サイクル"""
  _controller.enable_pause()

  # 3回サイクル
  for i in range(3):
    _controller.show_panel()
    assert_that(_controller.is_paused()).is_true()
    assert_that(_controller.visible).is_true()
    assert_that(_controller._has_been_shown).is_true()

    _controller.hide_panel()
    assert_that(_controller.is_paused()).is_false()
    assert_that(_controller.visible).is_false()
    # _has_been_shownは一度trueになったら維持される
    assert_that(_controller._has_been_shown).is_true()
