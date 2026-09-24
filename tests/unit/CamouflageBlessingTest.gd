# === 迷彩の加護 機能テスト ===
# テスト対象:
#   1. base_modifiers / エンチャントからのパラメータ算出
#   2. 発動で照準対象から外れ、発動地点が囮座標になること
#   3. 効果中の再発動は失敗し、使用回数を消費しないこと
#   4. 効果時間経過で照準対象へ戻ること
#   5. 自機スプライトのみ半透明になること（当たり判定・精霊は対象外）
#   6. 敵弾の追尾ロックから外れること（＝当たり判定は残ること）
class_name CamouflageBlessingTest
extends GdUnitTestSuite

const CamouflageBlessing := preload("res://scripts/player/CamouflageBlessing.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"


class MockHpNode:
  extends Node
  signal hp_changed(current_hp: int, max_hp: int)

  var max_hp := 10
  var current_hp := 10


class MockPlayer:
  extends Node2D

  var hp_node := MockHpNode.new()
  var camouflage_active := false
  var camouflage_alpha := 1.0

  func _ready() -> void:
    add_child(hp_node)
    add_to_group("players")

  func set_camouflage_visual(active: bool, alpha: float = 0.4) -> void:
    camouflage_active = active
    camouflage_alpha = alpha if active else 1.0


var _blessing: Node
var _player: MockPlayer


func before_test() -> void:
  _player = auto_free(MockPlayer.new())
  add_child(_player)
  _player.global_position = Vector2(100, 200)
  TargetService.register_player(_player)

  _blessing = auto_free(CamouflageBlessing.new())
  add_child(_blessing)
  _blessing.item_inst = ItemInstance.new(_make_proto())
  _blessing.on_equip(_player)


func after_test() -> void:
  TargetService.unregister_player()


func _make_proto(duration := 10.0, uses := 2) -> BlessingItem:
  var proto := BlessingItem.new()
  proto.id = "blessing_camouflage"
  proto.display_name = "迷彩の加護"
  proto.base_modifiers = {
    "camouflage_duration_sec": duration,
    "max_uses": uses,
    "blessing_cooldown_sec": 0.0,
  }
  return proto


func test_stats_from_base_modifiers() -> void:
  assert_float(_blessing.duration_sec).is_equal_approx(10.0, 0.001)
  assert_int(_blessing.max_uses).is_equal(2)
  assert_int(_blessing.get_uses_remaining()).is_equal(2)


func test_activate_makes_player_untargetable_with_decoy() -> void:
  assert_bool(TargetService.is_player_targetable()).is_true()

  assert_bool(_blessing.activate()).is_true()

  assert_bool(TargetService.is_player_targetable()).is_false()
  # 発動地点が囮座標になる。以後プレイヤーが動いても囮は動かない。
  assert_vector(TargetService.get_aim_position()).is_equal(Vector2(100, 200))
  _player.global_position = Vector2(500, 700)
  assert_vector(TargetService.get_aim_position()).is_equal(Vector2(100, 200))
  # 照準対象としては取得できないが、プレイヤー参照そのものは生きている
  assert_object(TargetService.get_aim_target()).is_null()
  assert_object(TargetService.get_player()).is_same(_player)

  assert_int(_blessing.get_uses_remaining()).is_equal(1)


func test_reactivation_during_effect_fails_without_consuming_use() -> void:
  assert_bool(_blessing.activate()).is_true()

  assert_bool(_blessing.activate()).is_false()

  assert_int(_blessing.get_uses_remaining()).is_equal(1)  # 消費は1回のみ


func test_effect_ends_after_duration() -> void:
  _blessing.duration_sec = 0.1
  assert_bool(_blessing.activate()).is_true()

  await await_millis(200)

  assert_bool(TargetService.is_player_targetable()).is_true()
  assert_bool(_blessing.is_active()).is_false()
  assert_vector(TargetService.get_aim_position()).is_equal(_player.global_position)


func test_player_sprite_alpha_only() -> void:
  var player: Node2D = auto_free(load(PLAYER_SCENE).instantiate())
  add_child(player)
  await await_idle_frame()

  player.set_camouflage_visual(true, 0.4)

  assert_float(player.get_node("AnimatedSprite2D").modulate.a).is_equal_approx(0.4, 0.001)
  # 当たり判定表示と精霊はスプライトの兄弟なので影響を受けない
  assert_float(player.get_node("HitJudgeContainer").modulate.a).is_equal_approx(1.0, 0.001)
  assert_float(player.get_node("FairyContainer").modulate.a).is_equal_approx(1.0, 0.001)

  player.set_camouflage_visual(false)
  assert_float(player.get_node("AnimatedSprite2D").modulate.a).is_equal_approx(1.0, 0.001)


func test_enemy_bullet_cannot_lock_camouflaged_player() -> void:
  var bullet: Node2D = auto_free(load("res://scenes/bullets/universal_bullet.tscn").instantiate())
  bullet.movement_config = null
  bullet.target_group = "players"
  add_child(bullet)
  bullet.set_process(false)
  bullet.global_position = Vector2(100, 0)

  assert_object(bullet._find_homing_target()).is_same(_player)

  _blessing.activate()

  assert_object(bullet._find_homing_target()).is_null()
