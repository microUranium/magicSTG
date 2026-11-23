# === プレイヤーとの距離で敵の透明度を変える部品（DistanceFade）のテスト ===
# ghost のシーンに組み込んだ状態で確認する。透明度・距離は調整で変わるため、
# 期待値は部品の設定値（near_distance / far_distance / min_alpha）と、シーンに設定された元の透明度から求める。
extends GdUnitTestSuite

const GHOST := preload("res://scenes/enemy/enemy_ghost.tscn")

var _world: Node2D
var _player: Node2D
var _saved_player: Node2D
var _ghost: Node2D
var _fade: Node
var _sprite: AnimatedSprite2D


func before_test() -> void:
  _world = Node2D.new()
  add_child(_world)
  TargetService.set_bullet_parent(_world)
  _saved_player = TargetService.get_player()
  _player = Node2D.new()
  _world.add_child(_player)
  TargetService.register_player(_player)

  _ghost = GHOST.instantiate()
  _world.add_child(_ghost)
  _fade = _ghost.get_node("DistanceFade")
  _sprite = _ghost.get_node("AnimatedSprite2D")


func after_test() -> void:
  TargetService.set_player_targetable(true)
  if is_instance_valid(_saved_player):
    TargetService.register_player(_saved_player)
  else:
    TargetService.unregister_player()
  TargetService.set_bullet_parent(null)
  _world.free()


## プレイヤーから distance だけ離れた位置に ghost を置き、透明度を更新して返す
func _alpha_at(distance: float) -> float:
  _player.global_position = Vector2(100, 100)
  _ghost.global_position = Vector2(100 + distance, 100)
  _fade._update_alpha()
  return _sprite.modulate.a


func test_max_alpha_is_scene_sprite_alpha() -> void:
  # 近いときの透明度は、シーンで画像に設定されている透明度（決め打ちしない）
  var fresh: Node = auto_free(GHOST.instantiate())
  var scene_alpha: float = (fresh.get_node("AnimatedSprite2D") as CanvasItem).modulate.a
  assert_float(_fade.get_max_alpha()).is_equal_approx(scene_alpha, 0.0001)
  assert_float(_fade.min_alpha).is_less(_fade.get_max_alpha())


func test_alpha_by_distance() -> void:
  var near: float = _fade.near_distance
  var far: float = _fade.far_distance
  var max_a: float = _fade.get_max_alpha()
  var min_a: float = _fade.min_alpha

  assert_float(_alpha_at(0.0)).is_equal_approx(max_a, 0.0001)
  assert_float(_alpha_at(near)).is_equal_approx(max_a, 0.0001)
  assert_float(_alpha_at((near + far) / 2.0)).is_equal_approx((max_a + min_a) / 2.0, 0.0001)
  assert_float(_alpha_at(far)).is_equal_approx(min_a, 0.0001)
  assert_float(_alpha_at(far * 3.0)).is_equal_approx(min_a, 0.0001)  # 最低値より薄くならない


func test_alpha_restored_without_player() -> void:
  _alpha_at(_fade.far_distance)
  TargetService.unregister_player()

  _fade._update_alpha()

  assert_float(_sprite.modulate.a).is_equal_approx(_fade.get_max_alpha(), 0.0001)


func test_uses_real_player_position_while_camouflaged() -> void:
  # 迷彩中（敵は囮を狙う）でも、透明度は実際のプレイヤーとの距離で決まる
  _player.global_position = Vector2(100, 100)
  _ghost.global_position = Vector2(100, 100)
  TargetService.set_player_targetable(false, Vector2(5000, 5000))

  _fade._update_alpha()

  assert_float(_sprite.modulate.a).is_equal_approx(_fade.get_max_alpha(), 0.0001)


func test_keeps_color_and_changes_only_alpha() -> void:
  # 被弾時の点滅（色の変更）を上書きしない
  _sprite.modulate = Color(1.0, 0.35, 0.35, _sprite.modulate.a)

  var alpha := _alpha_at(_fade.far_distance)

  assert_float(_sprite.modulate.r).is_equal_approx(1.0, 0.0001)
  assert_float(_sprite.modulate.g).is_equal_approx(0.35, 0.0001)
  assert_float(_sprite.modulate.b).is_equal_approx(0.35, 0.0001)
  assert_float(alpha).is_equal_approx(_fade.min_alpha, 0.0001)
