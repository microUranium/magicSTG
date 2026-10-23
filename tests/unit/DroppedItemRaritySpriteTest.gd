extends GdUnitTestSuite

const DROPPED_ITEM_SCENE := preload("res://scenes/items/dropped_item.tscn")


func _make_item(item_type: ItemBase.ItemType, levels: Array[int]) -> ItemInstance:
  var proto := ItemBase.new()
  proto.item_type = item_type
  var inst := ItemInstance.new(proto)
  for level in levels:
    inst.add_enchantment(Enchantment.new(), level)
  return inst


func _spawn_and_get_texture_path(inst: ItemInstance) -> String:
  var drop: DroppedItem = auto_free(DROPPED_ITEM_SCENE.instantiate())
  drop.item_instance = inst
  add_child(drop)
  return drop.sprite.texture.resource_path


func test_core_sprite_per_tier() -> void:
  var cases := {
    "res://assets/gfx/sprites/magic_tier12_sprite.png": [[] as Array[int], [1] as Array[int]],  # NORMAL, COMMON
    "res://assets/gfx/sprites/magic_tier34_sprite.png": [[3] as Array[int], [3, 3] as Array[int]],  # UNCOMMON, RARE
    "res://assets/gfx/sprites/magic_tier5_sprite.png": [[3, 4] as Array[int]],  # EPIC
    "res://assets/gfx/sprites/magic_tier6_sprite.png": [[5, 5] as Array[int]],  # LEGENDARY
  }
  for expected in cases:
    for levels in cases[expected]:
      var inst := _make_item(ItemBase.ItemType.ATTACK_CORE, levels)
      assert_str(_spawn_and_get_texture_path(inst)).is_equal(expected)


func test_blessing_sprite_per_tier() -> void:
  var cases := {
    "res://assets/gfx/sprites/blessing_tier12_sprite.png": [[] as Array[int], [2] as Array[int]],  # NORMAL, COMMON
    "res://assets/gfx/sprites/blessing_tier34_sprite.png":
    [[4] as Array[int], [2, 4] as Array[int]],  # UNCOMMON, RARE
    "res://assets/gfx/sprites/blessing_tier5_sprite.png": [[4, 4] as Array[int]],  # EPIC
    "res://assets/gfx/sprites/blessing_tier6_sprite.png": [[9] as Array[int]],  # LEGENDARY
  }
  for expected in cases:
    for levels in cases[expected]:
      var inst := _make_item(ItemBase.ItemType.BLESSING, levels)
      assert_str(_spawn_and_get_texture_path(inst)).is_equal(expected)


func test_missing_tier_falls_back_to_lower_tier() -> void:
  var drop: DroppedItem = auto_free(DROPPED_ITEM_SCENE.instantiate())
  var low := load("res://assets/gfx/sprites/magic_tier12_sprite.png") as Texture2D
  var textures: Array[Texture2D] = [low, low, null]

  assert_object(drop._pick_texture(textures, ItemInstance.RarityTier.LEGENDARY)).is_same(low)
  assert_object(drop._pick_texture(textures, ItemInstance.RarityTier.UNCOMMON)).is_same(low)
  (
    assert_object(drop._pick_texture([] as Array[Texture2D], ItemInstance.RarityTier.NORMAL))
    . is_null()
  )
