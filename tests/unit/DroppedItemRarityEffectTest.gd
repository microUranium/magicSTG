extends GdUnitTestSuite

const DROPPED_ITEM_SCENE := preload("res://scenes/items/dropped_item.tscn")


func _make_item(levels: Array[int]) -> ItemInstance:
  var proto := ItemBase.new()
  proto.item_type = ItemBase.ItemType.ATTACK_CORE
  var inst := ItemInstance.new(proto)
  for level in levels:
    inst.add_enchantment(Enchantment.new(), level)
  return inst


func _spawn(levels: Array[int]) -> DroppedItem:
  var drop: DroppedItem = auto_free(DROPPED_ITEM_SCENE.instantiate())
  drop.item_instance = _make_item(levels)
  add_child(drop)
  return drop


func _scene_root() -> Node:
  return get_tree().current_scene if get_tree().current_scene else get_tree().root


func test_no_effect_for_normal_and_common() -> void:
  for levels in [[] as Array[int], [1] as Array[int]]:
    var drop := _spawn(levels)
    assert_object(drop._rarity_effect).is_null()


func test_effect_per_tier_spawns_behind_sprite() -> void:
  var cases := {
    "RareDropEffectTier34": [[3] as Array[int], [3, 3] as Array[int]],  # UNCOMMON, RARE
    "RareDropEffectEpic": [[4, 4] as Array[int]],
    "RareDropEffectLegendary": [[5, 5] as Array[int]],
  }
  for effect_name in cases:
    for levels in cases[effect_name]:
      var drop := _spawn(levels)
      var effect := drop._rarity_effect
      assert_str(effect.name).is_equal(effect_name)
      assert_int(effect.get_index()).is_less(drop.sprite.get_index())
      assert_bool((effect.get_node("LoopAura") as CPUParticles2D).emitting).is_true()
      assert_bool((effect.get_node("SpawnRing") as CPUParticles2D).emitting).is_true()
      assert_bool((effect.get_node("PickupBurst") as CPUParticles2D).emitting).is_false()


func test_homing_delay_is_longer_for_high_tiers() -> void:
  var drop: DroppedItem = auto_free(DROPPED_ITEM_SCENE.instantiate())
  var normal := drop._get_homing_delay(ItemInstance.RarityTier.NORMAL)

  assert_float(drop._get_homing_delay(ItemInstance.RarityTier.RARE)).is_equal(normal)
  assert_float(drop._get_homing_delay(ItemInstance.RarityTier.EPIC)).is_greater(normal)
  assert_float(drop._get_homing_delay(ItemInstance.RarityTier.LEGENDARY)).is_greater(
    drop._get_homing_delay(ItemInstance.RarityTier.EPIC)
  )


func test_homing_delay_falls_back_to_default_when_unset() -> void:
  var drop: DroppedItem = auto_free(DROPPED_ITEM_SCENE.instantiate())
  var unset: Array[float] = []
  drop.homing_delay_sec_by_tier = unset

  assert_float(drop._get_homing_delay(ItemInstance.RarityTier.LEGENDARY)).is_equal(
    DroppedItem.DEFAULT_HOMING_DELAY_SEC
  )


func test_keeps_drifting_at_min_speed_until_homing_starts() -> void:
  var drop := _spawn([5, 5] as Array[int])  # LEGENDARY は吸い寄せ開始が遅い
  # 減速が終わった後、吸い寄せ開始前の区間を見る
  await await_millis(int((DroppedItem.DRIFT_DECEL_SEC + 0.1) * 1000))
  assert_object(drop.player).is_null()
  var before := drop.position

  await await_millis(300)

  assert_object(drop.player).is_null()
  assert_float(drop._drift_speed).is_equal_approx(drop.drift_min_speed, 0.01)
  assert_float(drop.position.distance_to(before)).is_greater(drop.drift_min_speed * 0.3 * 0.5)


func test_pickup_detaches_particles_so_they_outlive_the_item() -> void:
  var drop := _spawn([5, 5] as Array[int])
  var effect := drop._rarity_effect
  var burst: CPUParticles2D = effect.get_node("PickupBurst")
  var aura: CPUParticles2D = effect.get_node("LoopAura")

  effect.play_pickup()
  drop.free()

  assert_bool(is_instance_valid(burst)).is_true()
  assert_object(burst.get_parent()).is_same(_scene_root())
  assert_bool(burst.emitting).is_true()
  assert_object(aura.get_parent()).is_same(_scene_root())
  assert_bool(aura.emitting).is_false()

  # 再生し終わったら自動で解放される
  await await_millis(int((burst.lifetime + 0.2) * 1000))
  assert_bool(is_instance_valid(burst)).is_false()
