class_name EphemeralInventoryBreakageTest
extends GdUnitTestSuite

const ItemInstanceStubScript := preload("res://tests/stubs/ItemInstanceStub.gd")


func before_test() -> void:
  Ephemeralnventory.clear()
  Ephemeralnventory.set_rng_seed(12345)


func after_test() -> void:
  Ephemeralnventory.clear()


func _add_items(count: int) -> Array[ItemInstance]:
  var items: Array[ItemInstance] = []
  for i in range(count):
    var item: ItemInstance = ItemInstanceStubScript.dummy_item(
      "item%d" % i, ItemBase.ItemType.ATTACK_CORE
    )
    Ephemeralnventory.add(item)
    items.append(item)
  return items


func _broken_count(items: Array[ItemInstance]) -> int:
  return items.filter(func(item: ItemInstance): return item.is_broken).size()


func test_items_are_not_broken_by_default() -> void:
  var items := _add_items(10)

  assert_int(_broken_count(items)).is_equal(0)


func test_roll_breakage_breaks_about_sixty_percent() -> void:
  var items := _add_items(1000)

  Ephemeralnventory.roll_breakage()

  # 1000個・p=0.6 の標準偏差は約15.5。±5σ の範囲で確認する
  assert_int(_broken_count(items)).is_between(522, 678)


func test_roll_breakage_only_once_until_clear() -> void:
  var items := _add_items(100)

  Ephemeralnventory.roll_breakage()
  var first_count := _broken_count(items)
  Ephemeralnventory.roll_breakage()  # ゲームオーバーが二重に通知されたケース

  assert_int(_broken_count(items)).is_equal(first_count)


func test_roll_breakage_works_again_after_clear() -> void:
  _add_items(10)
  Ephemeralnventory.roll_breakage()
  Ephemeralnventory.clear()

  var items := _add_items(100)
  Ephemeralnventory.roll_breakage()

  assert_int(_broken_count(items)).is_greater(0)


func test_has_movable_items() -> void:
  assert_bool(Ephemeralnventory.has_movable_items()).is_false()

  var items := _add_items(2)
  items[0].is_broken = true
  assert_bool(Ephemeralnventory.has_movable_items()).is_true()

  items[1].is_broken = true
  assert_bool(Ephemeralnventory.has_movable_items()).is_false()
