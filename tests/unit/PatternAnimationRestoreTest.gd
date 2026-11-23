# === 敵のパターンが切り替えたアニメーションの戻しのテスト（EnemyPatternedAIBase） ===
# テスト対象:
#   1. パターンが正常に終わると、切り替え前のアニメーションに戻る
#   2. フェーズ切り替えなどでパターンを打ち切ると、その場で戻る。打ち切ったパターンの待機タイマーは
#      止まらず後から完了を通知してくるが、そのとき次のパターンのアニメーションを上書きしない
#      （以前は、次の attack 待機が「戻し先」を attack と記録し、attack のまま戻らなくなっていた）
#   3. restore_animation = false のパターンは戻さない
extends GdUnitTestSuite

var _world: Node2D
var _enemy: Node2D
var _sprite: AnimatedSprite2D


func before_test() -> void:
  _world = Node2D.new()
  add_child(_world)
  _enemy = Node2D.new()
  _sprite = AnimatedSprite2D.new()
  _sprite.name = "AnimatedSprite2D"
  var frames := SpriteFrames.new()  # "default" は最初からある
  frames.add_animation("attack")
  # コマが無いアニメーションには play() で切り替わらないので、1コマずつ入れておく
  var tex := PlaceholderTexture2D.new()
  frames.add_frame("default", tex)
  frames.add_frame("attack", tex)
  _sprite.sprite_frames = frames
  _enemy.add_child(_sprite)
  _world.add_child(_enemy)
  _sprite.play("default")


func after_test() -> void:
  _world.free()


func _stay(seconds: float, anim := "", restore := true) -> EnemyPatternResource:
  var p := EnemyPatternResource.new()
  p.movement_type = EnemyPatternResource.MovementType.STAY_IN_PLACE
  p.move_time = seconds
  p.change_animation = not anim.is_empty()
  p.animation_name = anim
  p.restore_animation = restore
  return p


func _start_ai(patterns: Array[EnemyPatternResource]) -> EnemyPatternedAIBase:
  var ai := EnemyPatternedAIBase.new()
  ai.patterns = patterns
  _enemy.add_child(ai)  # _ready で最初のパターンが始まる
  return ai


func test_animation_restored_when_pattern_finishes() -> void:
  _start_ai([_stay(0.2, "attack"), _stay(10.0)])
  assert_str(_sprite.animation).is_equal("attack")

  await await_millis(350)

  assert_str(_sprite.animation).is_equal("default")


func test_cancel_restores_and_stale_timer_does_not_override_next_pattern() -> void:
  var ai := _start_ai([_stay(0.3, "attack"), _stay(10.0)])
  await await_millis(100)

  # フェーズ切り替え：打ち切った時点で戻る
  ai._cancel_current_pattern()
  assert_str(_sprite.animation).is_equal("default")

  # 次のフェーズも attack の待機から始まる
  var next: Array[EnemyPatternResource] = [_stay(0.5, "attack"), _stay(10.0)]
  ai.patterns = next
  ai._idx = 0
  ai._next_pattern()
  assert_str(_sprite.animation).is_equal("attack")

  # 打ち切った待機（0.3秒）のタイマーが後から届いても、再生中の attack は上書きしない
  await await_millis(300)
  assert_str(_sprite.animation).is_equal("attack")

  # 次の待機（0.5秒）が終わると default に戻る（attack のまま残らない）
  await await_millis(350)
  assert_str(_sprite.animation).is_equal("default")


func test_animation_kept_when_restore_disabled() -> void:
  _start_ai([_stay(0.2, "attack", false), _stay(10.0)])

  await await_millis(350)

  assert_str(_sprite.animation).is_equal("attack")
