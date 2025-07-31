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

  func initialize(_actor, _damage):
    initialize_called = true
    damage = _damage

  func set_target_group(group: String):
    enemy_group = group

  # 何もしない body_entered を発火可能にする
  func fire_area_entered():
    emit_signal("area_entered", self)


## UniversalAttackCore スクリプトのパス
const UniversalAttackCore := preload("res://scripts/core/UniversalAttackCore.gd")

var core: UniversalAttackCore
var dummy_parent: Node2D
var dummy_actor: Node2D
var stub_scene: PackedScene


func before() -> void:
  ## ツリーに親ノード（弾の親）を用意
  dummy_parent = auto_free(Node2D.new())
  get_tree().root.add_child(dummy_parent)

  ## スタブビームを PackedScene に変換
  var beam_node := StubBeam.new()
  beam_node.name = "StubBeam"

  stub_scene = PackedScene.new()
  stub_scene.pack(beam_node)

  ## コアを生成 & 設定
  core = auto_free(UniversalAttackCore.new())
  core.cooldown_sec = 0.1  # AttackCoreBase 側 export 想定

  # AttackPatternを設定（ビーム用）
  var pattern := AttackPattern.new()
  pattern.pattern_type = AttackPattern.PatternType.BEAM
  pattern.beam_scene = stub_scene
  pattern.beam_duration = 0.2  # 削除テスト用
  pattern.damage = 10
  pattern.target_group = "enemies"
  core.attack_pattern = pattern

  dummy_parent.add_child(core)

  ## _owner_actor を設定（ビーム位置合わせ用）
  dummy_actor = auto_free(Node2D.new())
  dummy_parent.add_child(dummy_actor)
  core.set_owner_actor(dummy_actor)  # 正式なセッターを使用

  ## TargetServiceのモック設定（テスト環境用）
  _setup_target_service_mock()

  ## コアの状態を初期化（ready状態にする）
  core._cooling = false
  core._paused = false
  core.auto_start = false  # 自動開始を無効化


func _setup_target_service_mock():
  """TargetServiceのモックを設定"""
  # TargetServiceがnullの場合にdummy_parentを返すようにモック
  if not Engine.has_singleton("TargetService"):
    # シンプルなモックとして、グローバルにTargetServiceの代替を設定
    var mock_service = Node.new()
    mock_service.set_script(GDScript.new())
    mock_service.get_script().source_code = """
extends Node

func get_bullet_parent():
  return null  # 意図的にnullを返してフォールバック動作をテスト

func get_player_position() -> Vector2:
  return Vector2(200, 200)

func get_player() -> Node2D:
  return null
"""
    mock_service.get_script().reload()
    mock_service.name = "TargetService"
    get_tree().root.add_child(mock_service)


func test_fire_creates_and_destroys_beam() -> void:
  ## 発射
  core.trigger()
  await get_tree().process_frame

  ## ビームが生成されているか確認
  var beams: Array[StubBeam] = []
  _find_beams_recursive(get_tree().root, beams)

  if beams.size() > 0:
    var beam: StubBeam = beams[0]
    assert_that(beam).is_not_null()
    assert_bool(beam.is_inside_tree()).is_true()
    assert_bool(beam.initialize_called).is_true()
    assert_int(beam.damage).is_equal(10)
    assert_str(beam.enemy_group).is_equal("enemies")

    ## beam_duration 経過後に自動で queue_free
    await get_tree().create_timer(0.25).timeout
    assert_bool(not is_instance_valid(beam) or beam.is_queued_for_deletion()).is_true()
  else:
    # ビームが見つからない場合はテスト失敗
    push_error("No beam found - trigger() might have failed or beam was not created")
    assert_int(beams.size()).is_greater_equal(1)

  # テスト終了時に残っているビームをクリーンアップ
  await _cleanup_existing_beams()


func _find_beams_recursive(node: Node, beams: Array[StubBeam]):
  """再帰的にStubBeamを検索"""
  if node is StubBeam:
    beams.append(node)

  for child in node.get_children():
    _find_beams_recursive(child, beams)


func _cleanup_existing_beams():
  """既存のビームを全て削除"""
  var existing_beams: Array[StubBeam] = []
  _find_beams_recursive(get_tree().root, existing_beams)

  for beam in existing_beams:
    if is_instance_valid(beam):
      beam.queue_free()

  await get_tree().process_frame


func test_beam_with_custom_settings() -> void:
  ## 前のテストの残骸をクリーンアップ
  await _cleanup_existing_beams()

  ## コアの状態をリセット（クールダウン解除）
  core._cooling = false
  core._paused = false

  ## カスタム設定でビームパターンを更新
  var custom_pattern := AttackPattern.new()
  custom_pattern.pattern_type = AttackPattern.PatternType.BEAM
  custom_pattern.beam_scene = stub_scene
  custom_pattern.beam_duration = 5.0  # テスト中に削除されないよう長めに設定
  custom_pattern.damage = 25
  custom_pattern.target_group = "test_enemies"
  core.attack_pattern = custom_pattern

  ## 発射
  core.trigger()
  await get_tree().process_frame

  ## カスタム設定が反映されているか
  var beams: Array[StubBeam] = []
  _find_beams_recursive(get_tree().root, beams)

  if beams.size() > 0:
    var beam: StubBeam = beams[0]
    assert_int(beam.damage).is_equal(25)
    assert_str(beam.enemy_group).is_equal("test_enemies")
  else:
    push_error("No beam found in custom settings test")
    assert_int(beams.size()).is_greater_equal(1)
