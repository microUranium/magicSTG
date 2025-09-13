extends Control

@onready var switch_to_equipment_button: Button = $SwitchToEquipmentButton
@onready var switch_to_s1_intro_button: Button = $"SwitchToStageButton_S1-1"
@onready var switch_to_s1_boss_button: Button = $"SwitchToStageButton_S1-2"


func _ready() -> void:
  switch_to_equipment_button.pressed.connect(_on_switch_to_equipment_pressed)
  switch_to_s1_intro_button.pressed.connect(_on_switch_to_s1_intro_pressed)
  switch_to_s1_boss_button.pressed.connect(_on_switch_to_s1_boss_pressed)


func _unhandled_input(event: InputEvent) -> void:
  if event.is_pressed():
    _start_stage_with_random_seed()


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
