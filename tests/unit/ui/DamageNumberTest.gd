# === DamageNumber デバッグ表示テスト ===
extends GdUnitTestSuite
class_name DamageNumberTest

const DamageNumberScene = preload("res://scripts/ui/DamageNumber.gd")


func test_label_shows_damage_amount() -> void:
  var dn := DamageNumberScene.new()
  dn.amount = 42
  dn.is_invincible = false
  add_child(dn)
  await await_idle_frame()

  var label := dn.get_child(0) as Label
  assert_object(label).is_not_null()
  assert_str(label.text).is_equal("42")

  dn.queue_free()


func test_label_shows_miss_when_invincible() -> void:
  var dn := DamageNumberScene.new()
  dn.amount = 10
  dn.is_invincible = true
  add_child(dn)
  await await_idle_frame()

  var label := dn.get_child(0) as Label
  assert_str(label.text).is_equal("MISS")

  dn.queue_free()


func test_invincible_uses_gray_color() -> void:
  var dn := DamageNumberScene.new()
  dn.is_invincible = true
  assert_that(dn._text_color()).is_equal(Color(0.6, 0.6, 0.6))
  dn.free()


func test_large_damage_uses_orange_color() -> void:
  var dn := DamageNumberScene.new()
  dn.amount = 100
  dn.is_invincible = false
  assert_that(dn._text_color()).is_equal(Color(1.0, 0.4, 0.2))
  dn.free()


func test_auto_frees_after_lifetime() -> void:
  var dn := DamageNumberScene.new()
  dn.amount = 5
  add_child(dn)
  await await_idle_frame()

  # LIFETIME(0.6s) 経過後に自動削除される
  await await_millis(int(DamageNumberScene.LIFETIME * 1000) + 200)

  assert_bool(is_instance_valid(dn)).is_false()
