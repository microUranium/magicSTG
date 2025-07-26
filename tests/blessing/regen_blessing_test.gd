class_name RegenBlessingTest
extends GdUnitTestSuite


class MockHpNode:
  extends Node
  signal hp_changed(current_hp: int, max_hp: int)


class MockPlayer:
  extends Node
  signal healing_received(amount: int)

  var hp_node := MockHpNode.new()

  func _ready():
    add_child(hp_node)


const RegenBlessing := preload("res://scripts/player/RegenBlessing.gd")

var blessing: Node
var player: MockPlayer


func before() -> void:
  var _proto = BlessingItem.new()
  _proto.id = "proto_test"
  _proto.display_name = "テスト加護"
  _proto.base_modifiers = {}

  ## 擬似プレイヤーをツリーに追加
  player = auto_free(MockPlayer.new())
  get_tree().root.add_child(player)

  ## 加護をインスタンス化してツリーに追加
  blessing = auto_free(RegenBlessing.new())
  var _heal_timer: Timer = auto_free(Timer.new())
  _heal_timer.name = "HealTimer"
  blessing.heal_interval = 0.1  # テストを高速化
  blessing.heal_amount = 3
  blessing._proto = _proto
  get_tree().root.add_child(blessing)
  blessing.add_child(_heal_timer)

  blessing._ready()
  blessing.on_equip(player)
  blessing._connect_signals()


func test_healing_occurs_after_interval() -> void:
  assert_bool(blessing._cooling).is_true()
  assert_bool(blessing._healable).is_false()

  await get_tree().create_timer(0.2).timeout  # 0.2 秒待つ

  assert_bool(blessing._cooling).is_false()
  assert_bool(blessing._healable).is_false()

  ## HP を減らす → _healable フラグが立つ
  player.hp_node.emit_signal("hp_changed", 5, 10)
  assert_bool(blessing._healable).is_true()

  await assert_signal(blessing).wait_until(200).is_emitted("healing_done", [blessing.heal_amount])


func test_no_heal_when_full_hp() -> void:
  ## フル HP を通知（_healable = false）
  player.hp_node.emit_signal("hp_changed", 10, 10)
  assert_bool(blessing._healable).is_false()

  ## heal_interval 待っても healing_done は発火しない
  await assert_signal(blessing).wait_until(200).is_not_emitted("healing_done")
