class_name BeamCoreTest
extends GdUnitTestSuite


## テストに使うスタブビーム ------------------------------------------------------
class StubBeam:
  extends Area2D
  var initialize_called: bool = false
  var damage: int
  var desired_length: float
  var owner_path: NodePath
  var enemy_group: String

  func initialize(_actor):
    initialize_called = true

  # 何もしない body_entered を発火可能にする
  func fire_area_entered():
    emit_signal("area_entered", self)


## AttackCore スクリプトのパス
const BeamCore := preload("res://scripts/player/BeamCore.gd")

var core: Node
var dummy_parent: Node2D
var dummy_actor: Node2D
var stub_scene: PackedScene


func before() -> void:
  ## ツリーに親ノード（弾の親）を用意
  dummy_parent = auto_free(Node2D.new())
  get_tree().root.add_child(dummy_parent)

  ## スタブビームを PackedScene に変換
  var beam_node := StubBeam.new()
  stub_scene = PackedScene.new()
  stub_scene.pack(beam_node)

  ## コアを生成 & 設定
  core = auto_free(BeamCore.new())
  core.beam_scene = stub_scene
  core.beam_duration = 0.2  # テスト高速化
  core.cooldown_sec = 0.1  # AttackCoreBase 側 export 想定
  dummy_parent.add_child(core)

  ## _owner_actor を設定（ビーム位置合わせ用）
  dummy_actor = auto_free(Node2D.new())
  dummy_parent.add_child(dummy_actor)
  core._owner_actor = dummy_actor  # 基底クラスの protected 変数を直接アクセス


func test_fire_creates_and_destroys_beam() -> void:
  ## 発射
  await assert_signal(core).wait_until(300).is_emitted("core_fired")

  ## ビームが生成され親についたか
  var beam: StubBeam = core.beam_instance
  assert_that(beam).is_not_null()
  assert_bool(beam.is_inside_tree()).is_true()
  assert_bool(beam.initialize_called).is_true()

  ## beam_duration 経過後に自動で queue_free
  await get_tree().create_timer(0.25).timeout
  assert_that(beam).is_null()
  # Core が自動でクールダウン状態に入る (_cooling == true)
  assert_bool(core._cooling).is_true()


func test_pausing_frees_beam() -> void:
  ## 発射
  await assert_signal(core).wait_until(300).is_emitted("core_fired")
  var beam: StubBeam = core.beam_instance
  await get_tree().process_frame
  assert_that(beam).is_not_null()

  core._paused = true
  core._process(0.0)
  await get_tree().process_frame
  assert_that(beam).is_null()
