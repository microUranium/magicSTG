class_name InventoryServiceTest
extends GdUnitTestSuite

const ItemInstanceStubScript := preload("res://tests/stubs/ItemInstanceStub.gd")

var emmiter


func before() -> void:
  # InventoryService の初期化
  InventoryService.clear()


func test_try_add_and_remove() -> void:
  var item := ItemInstanceStub.dummy_item("uid1", ItemBase.ItemType.ATTACK_CORE)

  var result = InventoryService.try_add(item)

  assert_int(InventoryService.get_items().size()).is_equal(1)
  assert_bool(result).is_true()

  InventoryService.remove(item)

  assert_int(InventoryService.get_items().size()).is_equal(0)


func test_try_add_full() -> void:
  for i in range(InventoryService.get_max_size()):
    InventoryService.try_add(
      ItemInstanceStub.dummy_item("uid%d" % i, ItemBase.ItemType.ATTACK_CORE)
    )

  var item := ItemInstanceStub.dummy_item("uid_full", ItemBase.ItemType.ATTACK_CORE)
  var result = InventoryService.try_add(item)

  assert_bool(result).is_false()
  assert_int(InventoryService.get_items().size()).is_equal(InventoryService.get_max_size())


func test_clear_inventory() -> void:
  InventoryService.clear()

  assert_int(InventoryService.get_items().size()).is_equal(0)
