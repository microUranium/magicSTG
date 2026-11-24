# === boss_vampire の炎の突進のテスト（BossVampireAI） ===
# テスト対象:
#   1. 炎の突進を始める時点の HP が firerush_enhanced_hp_ratio を上回っていれば、従来の炎の突進（44本）
#   2. firerush_enhanced_hp_ratio 以下なら強化版：右端→左端→上端→下端から撃ったあと、
#      上端に左から右へ18本・右から左へ18本並べた炎が、それぞれプレイヤーを狙う
# 炎を実際に出す _spawn_firerush を記録用に差し替え、出した順番・向き・位置を確かめる
extends GdUnitTestSuite

const HP_NODE := preload("res://scripts/player/HpNode.gd")
const MAX_HP := 1000


class SpyAI:
  extends "res://scripts/enemy/BossVampireAI.gd"
  var spawned: Array = []  # [angle, position]

  func _ready() -> void:
    pass  # フェーズの設定は使わない

  func _spawn_firerush(angle: float, position: Vector2) -> void:
    spawned.append([angle, position])


var _world: Node2D
var _enemy: Node2D
var _hp: Node
var _ai: SpyAI
var _player: Node2D
var _saved_player: Node2D
var _saved_time_scale: float


func before_test() -> void:
  _saved_time_scale = Engine.time_scale
  Engine.time_scale = 10.0  # 待ち時間を縮める
  _world = Node2D.new()
  add_child(_world)
  _enemy = Node2D.new()
  _hp = HP_NODE.new()
  _hp.name = "HpNode"
  _hp.max_hp = MAX_HP
  _enemy.add_child(_hp)
  _world.add_child(_enemy)
  _ai = SpyAI.new()
  _enemy.add_child(_ai)
  _ai.enemy_node = _enemy

  _saved_player = TargetService.get_player()
  _player = Node2D.new()
  _world.add_child(_player)
  _player.global_position = Vector2(300, 700)
  TargetService.register_player(_player)


func after_test() -> void:
  Engine.time_scale = _saved_time_scale
  if is_instance_valid(_saved_player):
    TargetService.register_player(_saved_player)
  else:
    TargetService.unregister_player()
  _world.free()


func _set_hp(value: int) -> void:
  _hp.take_damage(_hp.current_hp - value)


func _expected_aim_angle(pos: Vector2) -> float:
  return rad_to_deg((_player.global_position - pos).angle()) - 90.0


func test_normal_firerush_while_hp_above_ratio() -> void:
  _set_hp(floori(MAX_HP * _ai.firerush_enhanced_hp_ratio) + 1)

  await _ai._attack_firerush()

  assert_int(_ai.spawned.size()).is_equal(44)
  assert_float(_ai.spawned[0][0]).is_equal(_ai.FIRERUSH_TO_LEFT)
  assert_vector(_ai.spawned[0][1]).is_equal(Vector2(895, 64))


func test_enhanced_firerush_at_ratio() -> void:
  _set_hp(floori(MAX_HP * _ai.firerush_enhanced_hp_ratio))

  await _ai._attack_firerush()

  var s := _ai.spawned
  assert_int(s.size()).is_equal(4 + 4 + 4 + 3 + 18 + 18)

  var expected_edges := [
    [
      _ai.FIRERUSH_TO_LEFT,
      [Vector2(895, 64), Vector2(895, 320), Vector2(895, 576), Vector2(895, 832)]
    ],
    [_ai.FIRERUSH_TO_RIGHT, [Vector2(1, 192), Vector2(1, 448), Vector2(1, 704), Vector2(1, 960)]],
    [_ai.FIRERUSH_TO_DOWN, [Vector2(64, 1), Vector2(320, 1), Vector2(576, 1), Vector2(832, 1)]],
    [_ai.FIRERUSH_TO_UP, [Vector2(192, 959), Vector2(448, 959), Vector2(704, 959)]],
  ]
  var i := 0
  for group in expected_edges:
    for pos in group[1]:
      assert_float(s[i][0]).is_equal(group[0])
      assert_vector(s[i][1]).is_equal(pos)
      i += 1

  # 上端の列：左から右へ18本、次に右から左へ18本。どれもプレイヤーを狙う
  for k in range(18):
    var pos := Vector2(32 + k * 32, 1)
    assert_vector(s[i][1]).is_equal(pos)
    assert_float(s[i][0]).is_equal_approx(_expected_aim_angle(pos), 0.001)
    i += 1
  for k in range(18):
    var pos := Vector2(864 - k * 32, 1)
    assert_vector(s[i][1]).is_equal(pos)
    assert_float(s[i][0]).is_equal_approx(_expected_aim_angle(pos), 0.001)
    i += 1


func test_aimed_angle_points_at_player() -> void:
  # _spawn_firerush の angle は「撃つ方向 - 90°」。狙った角度から戻した方向がプレイヤーを向く
  var pos := Vector2(32, 1)
  var angle := _ai._angle_to_player_from(pos)
  var dir := Vector2.RIGHT.rotated(deg_to_rad(angle + 90.0))
  assert_vector(dir).is_equal_approx(
    (_player.global_position - pos).normalized(), Vector2(0.001, 0.001)
  )


func test_warning_line_reaches_across_play_area() -> void:
  # 上端の角の近くから反対側の角を狙っても、警告線が画面内で途切れない長さがある
  const PLAY_SIZE := Vector2(896, 960)
  var firerush: Node = auto_free(_ai.firerush_scene.instantiate())
  var config: AttackWarningConfig = firerush.get_node("EnemyAI").warning_config
  assert_float(config.warning_length).is_greater_equal(PLAY_SIZE.length())
