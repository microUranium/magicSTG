extends Control

@onready var switch_to_equipment_button: Control = $VBoxContainer/Equipment/ClickArea
@onready var switch_to_stage_select_button: Control = $VBoxContainer/StageSelect/ClickArea
@onready var _equipment_label: Label = $VBoxContainer/Equipment/Label
@onready var _stage_select_label: Label = $VBoxContainer/StageSelect/Label
#@onready var switch_to_s1_intro_button: Button = $"SwitchToStageButton_S1-1"
#@onready var switch_to_s1_boss_button: Button = $"SwitchToStageButton_S1-2"

#---------------------------------------------------------------------
# Constants
#---------------------------------------------------------------------
const HOVER_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const HOVER_DURATION := 0.15

# Label -> 実行中のホバーTween
var _hover_tweens: Dictionary = {}


func _ready() -> void:
  GameFlow.play_menu_bgm()

  _setup_click_area(switch_to_equipment_button, _equipment_label, _on_switch_to_equipment_pressed)
  #switch_to_s1_intro_button.pressed.connect(_on_switch_to_s1_intro_pressed)
  #switch_to_s1_boss_button.pressed.connect(_on_switch_to_s1_boss_pressed)
  _setup_click_area(
    switch_to_stage_select_button, _stage_select_label, _on_switch_to_stage_select_pressed
  )


func _setup_click_area(area: Control, label: Label, handler: Callable) -> void:
  """ClickArea(Control)のクリック検出とホバー検出をセットアップ"""
  if not area:
    push_warning("TitleScreen: Click area not found")
    return

  # マウスフィルターを設定して入力を受け取る
  area.mouse_filter = Control.MOUSE_FILTER_STOP

  # Controlには pressed シグナルが無いため gui_input で検出
  area.gui_input.connect(_on_click_area_gui_input.bind(area, handler))

  # ホバー検出
  area.mouse_entered.connect(_on_area_hover_start.bind(label))
  area.mouse_exited.connect(_on_area_hover_end.bind(label))


func _on_click_area_gui_input(event: InputEvent, area: Control, handler: Callable) -> void:
  """ClickAreaの左クリックを検出してハンドラを呼ぶ"""
  if event is InputEventMouseButton:
    if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
      area.accept_event()
      _play_click_sfx()
      handler.call()


#---------------------------------------------------------------------
# Hover Event Handlers
#---------------------------------------------------------------------
func _on_area_hover_start(label: Label) -> void:
  """ボタンにホバー開始"""
  _animate_label_scale(label, HOVER_SCALE)
  _play_hover_sfx()


func _on_area_hover_end(label: Label) -> void:
  """ボタンからホバー解除"""
  _animate_label_scale(label, NORMAL_SCALE)


func _animate_label_scale(label: Label, target_scale: Vector2) -> void:
  """Labelのスケールをアニメーション"""
  if not label:
    return

  # 既存のTweenをキャンセル
  var tween: Tween = _hover_tweens.get(label)
  if tween and tween.is_valid():
    tween.kill()

  # 新しいTweenを作成
  tween = create_tween()
  tween.set_ease(Tween.EASE_OUT)
  tween.set_trans(Tween.TRANS_BACK)
  tween.tween_property(label, "scale", target_scale, HOVER_DURATION)
  _hover_tweens[label] = tween


#---------------------------------------------------------------------
# Sound Effects
#---------------------------------------------------------------------
func _play_hover_sfx() -> void:
  """ホバー時のSFX再生"""
  StageSignals.emit_signal("sfx_play_requested", "ui_hover", Vector2.INF, -5.0, 1.0)


func _play_click_sfx() -> void:
  """クリック時のSFX再生"""
  # NOTE: カタログに "ui_click" が未登録のため、既存のUI音 "ui_cancel" を使用
  StageSignals.emit_signal("sfx_play_requested", "ui_cancel", Vector2.INF, 0.0, 1.0)


#func _unhandled_input(event: InputEvent) -> void:
#  if event.is_pressed():
#    _start_stage_with_random_seed()


func _start_stage_with_random_seed() -> void:
  """ランダムシードでステージ開始"""
  var pool_sequence := [{"pool": "stage2", "count": 10}, {"pool": "stage2_boss", "count": 1}]

  var random_seed := RandomSeedGenerator.generate_seed_with_pools(pool_sequence)
  print("TitleScreen: Generated random seed: %s" % random_seed)
  GameFlow.start_stage()


func _on_switch_to_s1_intro_pressed() -> void:
  """S1イントロボタン - 固定シード設定"""
  #var fixed_seed := "Ds1d11.intro-s2g1-s221-s211-s111-s112-s131-s1g1-Ds1d11.progression-s121-s1g1-s112-s141-s112-s1z1-Ds1d11.resolution"
  #var fixed_seed := "Ds2d11.intro-s231-s211-s241-s2g1-s231-s211-s221-Ds2d11.progression-s2z1-Ds2d11.resolution"
  var fixed_seed := "Ds3d11.intro-s331-s321-s311-s331-Ds3d11.progression-s322-s312-s3g1-s3z1-Ds3d11.resolution"
  RandomSeedGenerator.set_current_seed(fixed_seed)
  print("TitleScreen: Set fixed intro seed: %s" % fixed_seed)
  GameFlow.start_stage()


func _on_switch_to_s1_boss_pressed() -> void:
  """S1ボスボタン - 固定シード設定"""
  #var fixed_seed := "Ds1d12.intro-s113-s122-s1g3-s113-s142-Ds1d12.progression-s134-s1g2-s1g4-s1g3-s1g5-s1z3-s1z2-Ds1d12.resolution"
  #var fixed_seed := "s223-s213-s2g7-s234-s2g6-s213-s2g9-s2ga-s2g8-s2gb-s2z3-s2z2-Ds2d12.resolution"
  var fixed_seed := "Ds3d12.intro-s3z2-Ds3d12.resolution"
  RandomSeedGenerator.set_current_seed(fixed_seed)
  print("TitleScreen: Set fixed boss seed: %s" % fixed_seed)
  GameFlow.start_stage()


func _on_switch_to_equipment_pressed() -> void:
  GameFlow.start_equipment_screen()


func _on_switch_to_stage_select_pressed() -> void:
  GameFlow.start_stage_select_screen()
