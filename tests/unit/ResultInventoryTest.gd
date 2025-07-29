class_name ResultInventoryTest
extends GdUnitTestSuite

const ItemInstanceStubScript := preload("res://tests/stubs/ItemInstanceStub.gd")

var screen: Control
var grid
var result_inventory: ResultInventory
var inv_slot: ItemSlotPanel
var equip_slot: EquipSlotPanel


func before() -> void:
  InventoryService.clear()
  Ephemeralnventory.clear()
  screen = auto_free(preload("res://scenes/levels/result_inventory.tscn").instantiate())
  get_tree().root.add_child(screen)
  result_inventory = get_tree().root.get_node("ResultInventory")

  await get_tree().process_frame  # UI 初期化待ち

  grid = screen.get_node("InventoryPanel/ItemListPane/InventoryGrid")

  await get_tree().process_frame  # UI 更新待ち


func before_test() -> void:
  InventoryService.clear()
  Ephemeralnventory.clear()


func test_load_inventory() -> void:
  # インベントリの読み込み
  result_inventory._load_inventory()
  assert_int(grid.get_items().size()).is_equal(0)  # 初期状態ではアイテムなし

  # テスト用アイテムを仕込む
  var item_ac: ItemInstance = ItemInstanceStubScript.dummy_item(
    "core1", ItemBase.ItemType.ATTACK_CORE
  )
  InventoryService.try_add(item_ac)

  result_inventory._load_inventory()

  await get_tree().process_frame  # UI 更新待ち

  assert_int(grid.get_items().size()).is_equal(1)  # アイテムが1つ追加されているはず


func test_show_result_items() -> void:
  # 結果アイテムの表示
  result_inventory._show_result_items()
  assert_int(result_inventory.grid_results.get_items().size()).is_equal(0)  # 初期状態ではアイテムなし

  # テスト用結果アイテムを追加
  var item_result: ItemInstance = ItemInstanceStubScript.dummy_item(
    "result1", ItemBase.ItemType.ATTACK_CORE
  )
  Ephemeralnventory.add(item_result)

  await get_tree().process_frame  # UI 更新待ち

  result_inventory._show_result_items()
  assert_int(result_inventory.grid_results.get_items().size()).is_equal(1)  # 結果アイテムが1つ追加されているはず


func test_swap_to_each_grid() -> void:
  # テスト用結果アイテムを追加
  var item_result: ItemInstance = ItemInstanceStubScript.dummy_item(
    "result1", ItemBase.ItemType.ATTACK_CORE
  )
  Ephemeralnventory.add(item_result)

  result_inventory._load_inventory()
  result_inventory._show_result_items()

  await get_tree().process_frame  # UI 更新待ち

  assert_int(result_inventory.grid_inv.get_items().size()).is_equal(0)  # インベントリは空
  assert_int(result_inventory.grid_results.get_items().size()).is_equal(1)  # 結果アイテムが1つ

  result_inventory._on_swap_to_each_grid(
    result_inventory.grid_results.get_child(0), result_inventory.grid_results
  )

  await get_tree().process_frame  # UI 更新待ち

  assert_int(result_inventory.grid_inv.get_items().size()).is_equal(1)  # インベントリにアイテムが追加されているはず
  assert_int(result_inventory.grid_results.get_items().size()).is_equal(0)  # 結果アイテムが削除されているはず
  assert_int(Ephemeralnventory.get_items().size()).is_equal(0)  # 結果アイテムがエフェメラルから削除されているはず
  assert_int(InventoryService.get_items().size()).is_equal(1)  # インベントリにアイテムが追加されているはず

  await get_tree().process_frame  # UI 更新待ち

  result_inventory._on_swap_to_each_grid(
    result_inventory.grid_inv.get_child(0), result_inventory.grid_inv
  )

  assert_int(result_inventory.grid_inv.get_items().size()).is_equal(0)  # インベントリからアイテムが削除されているはず
  assert_int(result_inventory.grid_results.get_items().size()).is_equal(1)  # 結果アイテムに戻っているはず
  assert_int(Ephemeralnventory.get_items().size()).is_equal(1)  # 結果アイテムがエフェメラルに戻っているはず
  assert_int(InventoryService.get_items().size()).is_equal(0)  # インベントリは空に戻っているはず


func test_swap_request() -> void:
  # テスト用アイテムをインベントリに追加
  var item_result: ItemInstance = ItemInstanceStubScript.dummy_item(
    "result1", ItemBase.ItemType.ATTACK_CORE
  )
  Ephemeralnventory.add(item_result)

  var item_inv: ItemInstance = ItemInstanceStubScript.dummy_item(
    "inv1", ItemBase.ItemType.ATTACK_CORE
  )
  InventoryService.try_add(item_inv)

  result_inventory._load_inventory()
  result_inventory._show_result_items()

  await get_tree().process_frame  # UI 更新待ち

  var inv_item_panel: ItemSlotPanel = result_inventory.grid_inv.get_child(0)
  var result_item_panel: ItemSlotPanel = result_inventory.grid_results.get_child(0)

  result_inventory._swap_items(inv_item_panel, result_item_panel)

  await get_tree().process_frame  # UI 更新待ち

  inv_item_panel = result_inventory.grid_inv.get_child(0)
  result_item_panel = result_inventory.grid_results.get_child(0)

  assert_str(inv_item_panel.data.inst.uid).is_equal(item_result.uid)  # 結果アイテムがインベントリに移動
  assert_str(result_item_panel.data.inst.uid).is_equal(item_inv.uid)  # インベントリアイテムが結果に移動


func test_bring_all_items():  # 結果インベントリから全アイテムをインベントリに移動
  var result_items: Array[ItemInstance] = []
  for i in range(InventoryService.get_max_size() + 1):
    var item: ItemInstance = ItemInstanceStubScript.dummy_item(
      "result%d" % i, ItemBase.ItemType.ATTACK_CORE
    )
    Ephemeralnventory.add(item)
    result_items.append(item)

  result_inventory._load_inventory()
  result_inventory._show_result_items()

  await get_tree().process_frame  # UI 更新待ち

  result_inventory._on_bring_all_items_from_result_inventory_pressed()

  await get_tree().process_frame  # UI 更新待ち

  assert_int(result_inventory.grid_inv.get_items().size()).is_equal(InventoryService.get_max_size())  # インベントリに全アイテムが追加されているはず
  assert_int(result_inventory.grid_results.get_items().size()).is_equal(1)  # 結果アイテムが1つ残っているはず
