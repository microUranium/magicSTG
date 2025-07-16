extends GdUnitTestSuite

var player_scene: Player = preload("res://scenes/player/Player.tscn").instantiate()


func test_pick_up_queues_free_and_calls_player() -> void:
  var scene := preload("res://scenes/items/dropped_item.tscn")
  var drop: DroppedItem = scene.instantiate()
  var dummy_item := ItemInstance.new(ItemBase.new())
  var emmiter := monitor_signals(InventoryService)
  drop.item_instance = dummy_item

  get_tree().root.add_child(drop)
  get_tree().root.add_child(player_scene)

  # 直接ハンドラを叩く（Area2D の body_entered シグナルと同等）
  drop._on_area_entered(player_scene)
  await get_tree().process_frame

  # Player にアイテムが渡り、ドロップは削除されている
  await assert_signal(emmiter).wait_until(50).is_emitted("changed")
  var drop_items := get_tree().root.get_children().filter(func(c): return c is DroppedItem)
  assert_int(drop_items.size()).is_equal(0)  # ドロップアイテムが削除されている
