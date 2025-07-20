class_name ItemGridTest
extends GdUnitTestSuite

const ItemInstanceStubScript := preload("res://tests/stubs/ItemInstanceStub.gd")

var inv_pane
var grid: ItemGrid
const PER_PAGE := 30  # 実装内定義


func before() -> void:
  inv_pane = auto_free(preload("res://scenes/ui/controller/inventory_panel.tscn").instantiate())
  grid = inv_pane.get_node("ItemListPane/InventoryGrid")
  get_tree().root.add_child(grid)


func test_recalc_pages() -> void:
  var items: Array[ItemPanelData] = []
  for n in 35:
    var item_panel: ItemPanelData = auto_free(ItemPanelData.new())
    item_panel.inst = ItemInstanceStubScript.dummy_item("uid_%d" % n, ItemBase.ItemType.BLESSING)
    items.append(item_panel)
  grid.set_items(items)
  await get_tree().process_frame
  assert_int(grid.max_page()).is_equal(2)
  assert_int(grid.current_page()).is_equal(0)


func test_sort_by_type_attack_first() -> void:
  var list := [
    ItemInstanceStubScript.dummy_item("b1", ItemBase.ItemType.BLESSING),
    ItemInstanceStubScript.dummy_item("a1", ItemBase.ItemType.ATTACK_CORE),
    ItemInstanceStubScript.dummy_item("b2", ItemBase.ItemType.BLESSING)
  ]

  var items: Array[ItemPanelData] = []

  for item in list:
    var item_panel: ItemPanelData = auto_free(ItemPanelData.new())
    item_panel.inst = item
    items.append(item_panel)

  grid.set_items(items)
  grid._on_sort_requested(ItemBase.ItemType.ATTACK_CORE)
  await get_tree().process_frame

  var first_slot: ItemSlotPanel = grid.get_child(0)
  assert_bool(first_slot.data.inst.prototype.item_type == ItemBase.ItemType.ATTACK_CORE).is_true()


func after_test() -> void:
  get_tree().root.remove_child(grid)
