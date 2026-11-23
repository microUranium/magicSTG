# === boss_bird_swamp の分身の火の玉が、本体の HP が下がるまで動かないことのテスト（FireBallDecoyAI） ===
# テスト対象:
#   1. 本体の HP が move_start_hp_ratio を上回っている間は、停止時間を終えても動き出さない
#   2. 本体の HP が move_start_hp_ratio 以下になると、待っていた分身はその場で動き出す
#   3. 待っている間も攻撃のコアは残っている（攻撃は続ける）
# 割合は調整で変わるため、期待値は move_start_hp_ratio から求める
extends GdUnitTestSuite

const PLAY_AREA_SCRIPT := preload("res://scripts/autoload/PlayArea.gd")
const PLAY_RECT := Rect2(0, 0, 896, 896)
const DECOY := preload("res://scenes/enemy/enemy_fire_ball_decoy.tscn")
const HP_NODE := preload("res://scripts/player/HpNode.gd")
const OWNER_MAX_HP := 1000

var _saved_rect: Rect2
var _world: Node2D
var _owner: Node2D
var _owner_hp: Node
var _ai: FireBallDecoyAI


func before_test() -> void:
  _saved_rect = PLAY_AREA_SCRIPT._play_rect
  PLAY_AREA_SCRIPT._play_rect = PLAY_RECT
  _world = Node2D.new()
  add_child(_world)
  TargetService.set_bullet_parent(_world)

  _owner = Node2D.new()
  _owner_hp = HP_NODE.new()
  _owner_hp.name = "HpNode"
  _owner_hp.max_hp = OWNER_MAX_HP
  _owner.add_child(_owner_hp)
  _world.add_child(_owner)
  _owner.global_position = Vector2(448, 200)

  var decoy: Node2D = DECOY.instantiate()
  _world.add_child(decoy)
  _ai = decoy.get_node("EnemyAI")
  _ai.initialize(0, _owner)


func after_test() -> void:
  PLAY_AREA_SCRIPT._play_rect = _saved_rect
  TargetService.set_bullet_parent(null)
  _world.free()


## 最初の位置に着いて攻撃しながら止まり、停止時間を終えて動いてよくなるのを待っている状態にする
func _wait_at_first_position() -> void:
  _ai._check_state_transitions()  # 最初の位置に着いた（INIT → STAY、攻撃を始める）
  _ai._waiting_for_unlock = true  # 停止時間を終えた


## 本体の HP を、動き出す境目の1つ上まで減らす
func _damage_owner_to_threshold() -> void:
  var hold_hp := floori(OWNER_MAX_HP * _ai.move_start_hp_ratio) + 1
  _owner_hp.take_damage(_owner_hp.current_hp - hold_hp)


func test_holds_position_while_owner_hp_above_ratio() -> void:
  assert_float(_ai.move_start_hp_ratio).is_greater(0.0)
  _wait_at_first_position()

  _damage_owner_to_threshold()

  assert_bool(_ai._move_unlocked).is_false()
  assert_int(_ai.current_state).is_equal(FireBallDecoyAI.MovementState.STAY)
  assert_int(_ai._pattern_cores.size()).is_greater(0)  # 止まっている間も攻撃は続ける


func test_starts_moving_when_owner_hp_reaches_ratio() -> void:
  _wait_at_first_position()
  _damage_owner_to_threshold()

  _owner_hp.take_damage(1)

  assert_bool(_ai._move_unlocked).is_true()
  assert_bool(_ai._waiting_for_unlock).is_false()
  assert_int(_ai.current_state).is_equal(FireBallDecoyAI.MovementState.MOVEMENT)


func test_unlocked_before_stay_ends_moves_after_stay() -> void:
  # 停止時間の途中で HP が境目以下になったときは、その場では動かず、停止時間を終えてから動く
  _ai._check_state_transitions()  # INIT → STAY
  _damage_owner_to_threshold()
  _owner_hp.take_damage(1)

  assert_bool(_ai._move_unlocked).is_true()
  assert_int(_ai.current_state).is_equal(FireBallDecoyAI.MovementState.STAY)
