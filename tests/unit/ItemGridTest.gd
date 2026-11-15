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
  grid._on_sort_requested(ItemGrid.SortMode.ATTACK_CORE_FIRST)
  await get_tree().process_frame

  var first_slot: ItemSlotPanel = grid.get_child(0)
  assert_bool(first_slot.data.inst.prototype.item_type == ItemBase.ItemType.ATTACK_CORE).is_true()


func test_sort_by_type_blessing_first_orders_by_id_then_uid() -> void:
  var items := _make_panels(
    [
      ItemInstanceStubScript.dummy_item_with_proto("u2", &"b_proto", ItemBase.ItemType.BLESSING),
      ItemInstanceStubScript.dummy_item_with_proto("u1", &"atk", ItemBase.ItemType.ATTACK_CORE),
      ItemInstanceStubScript.dummy_item_with_proto("u3", &"a_proto", ItemBase.ItemType.BLESSING),
      ItemInstanceStubScript.dummy_item_with_proto("u1", &"b_proto", ItemBase.ItemType.BLESSING),
    ]
  )
  grid.set_items(items)
  grid._on_sort_requested(ItemGrid.SortMode.BLESSING_FIRST)

  assert_array(_uids_with_proto(grid.get_items())).is_equal(
    ["a_proto:u3", "b_proto:u1", "b_proto:u2", "atk:u1"]
  )


func test_sort_by_rarity_descending() -> void:
  var low := ItemInstanceStubScript.dummy_item_with_proto("low", &"p", ItemBase.ItemType.BLESSING)
  var none := ItemInstanceStubScript.dummy_item_with_proto(
    "none", &"p", ItemBase.ItemType.ATTACK_CORE
  )
  var high := ItemInstanceStubScript.dummy_item_with_proto("high", &"p", ItemBase.ItemType.BLESSING)
  low.add_enchantment(Enchantment.new(), 2)
  high.add_enchantment(Enchantment.new(), 3)
  high.add_enchantment(Enchantment.new(), 2)

  grid.set_items(_make_panels([low, none, high]))
  grid._on_sort_requested(ItemGrid.SortMode.RARITY)

  assert_array(_uids(grid.get_items())).is_equal(["high", "low", "none"])


func test_sort_by_rarity_ties_order_by_id_then_uid() -> void:
  var b2 := ItemInstanceStubScript.dummy_item_with_proto("u2", &"b", ItemBase.ItemType.BLESSING)
  var a := ItemInstanceStubScript.dummy_item_with_proto("u9", &"a", ItemBase.ItemType.ATTACK_CORE)
  var b1 := ItemInstanceStubScript.dummy_item_with_proto("u1", &"b", ItemBase.ItemType.BLESSING)
  for inst in [b2, a, b1]:
    inst.add_enchantment(Enchantment.new(), 1)

  grid.set_items(_make_panels([b2, a, b1]))
  grid._on_sort_requested(ItemGrid.SortMode.RARITY)

  assert_array(_uids_with_proto(grid.get_items())).is_equal(["a:u9", "b:u1", "b:u2"])


func test_sort_button_cycles_attack_rarity_blessing() -> void:
  # before() の inv_pane はツリー外で @onready が未解決なので別インスタンスを使う
  var panel: InventoryPanel = auto_free(
    preload("res://scenes/ui/controller/inventory_panel.tscn").instantiate()
  )
  add_child(panel)
  var sort_btn: Button = panel.get_node("ItemListPane/Sort")
  panel._on_sort_pressed()
  assert_str(sort_btn.text).is_equal("ソート: レア度")
  panel._on_sort_pressed()
  assert_str(sort_btn.text).is_equal("ソート: 加護")
  panel._on_sort_pressed()
  assert_str(sort_btn.text).is_equal("ソート: 魔法")


func _make_panels(insts: Array) -> Array[ItemPanelData]:
  var items: Array[ItemPanelData] = []
  for inst in insts:
    var item_panel: ItemPanelData = auto_free(ItemPanelData.new())
    item_panel.inst = inst
    items.append(item_panel)
  return items


func _uids(items: Array[ItemPanelData]) -> Array:
  return items.map(func(d: ItemPanelData): return d.inst.uid)


func _uids_with_proto(items: Array[ItemPanelData]) -> Array:
  return items.map(func(d: ItemPanelData): return "%s:%s" % [d.inst.prototype.id, d.inst.uid])


func after_test() -> void:
  get_tree().root.remove_child(grid)
