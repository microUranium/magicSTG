extends GdUnitTestSuite

const SFXManagerScript = preload("res://scripts/autoload/SFXManager.gd")

var _sfx


func before_test() -> void:
  _sfx = SFXManagerScript.new()
  # ステアリングテスト用に小さいプールにする
  _sfx.pool_size_2d = 2
  _sfx.pool_size_ui = 2
  _sfx.catalog = _make_catalog()
  add_child(_sfx)
  await await_idle_frame()


func after_test() -> void:
  if is_instance_valid(_sfx):
    _sfx.queue_free()


func _make_catalog() -> SFXCatalog:
  var c := SFXCatalog.new()
  c.table["a"] = AudioStreamGenerator.new()
  c.table["b"] = AudioStreamGenerator.new()
  c.table["c"] = AudioStreamGenerator.new()
  return c


func _count_playing(pool) -> int:
  var n := 0
  for p in pool:
    if p.playing:
      n += 1
  return n


func test_same_frame_same_sound_is_coalesced() -> void:
  # 同フレームに同じ音を2回要求しても1音だけ鳴る
  _sfx._on_request("a", Vector2(10, 10), 0.0, 1.0)
  _sfx._on_request("a", Vector2(10, 10), 0.0, 1.0)
  await await_idle_frame()

  assert_int(_count_playing(_sfx._pool_2d)).is_equal(1)


func test_coalesce_exception_allows_multiple() -> void:
  # 例外指定した名前は同フレームでも複数鳴る
  var exceptions: Array[String] = ["a"]
  _sfx.coalesce_exceptions = exceptions

  _sfx._on_request("a", Vector2(10, 10), 0.0, 1.0)
  _sfx._on_request("a", Vector2(10, 10), 0.0, 1.0)
  await await_idle_frame()

  assert_int(_count_playing(_sfx._pool_2d)).is_equal(2)


func test_voice_stealing_when_pool_full() -> void:
  # プール(2)を満たしてさらに1件 → 最古が奪われ、総発音数は上限を維持
  _sfx._on_request("a", Vector2(10, 10), 0.0, 1.0)  # 最古
  _sfx._on_request("b", Vector2(20, 20), 0.0, 1.0)
  _sfx._on_request("c", Vector2(30, 30), 0.0, 1.0)  # スチール発動
  await await_idle_frame()

  # 上限（2）を超えない
  assert_int(_count_playing(_sfx._pool_2d)).is_equal(2)

  # 新しい音 c は鳴っており、最古の a は奪われて消えている
  var streams := [_sfx._pool_2d[0].stream, _sfx._pool_2d[1].stream]
  assert_bool(_sfx.catalog.table["c"] in streams).is_true()
  assert_bool(_sfx.catalog.table["a"] in streams).is_false()


func test_routing_ui_vs_2d() -> void:
  # 位置 INF は UIプール、それ以外は 2Dプールへ
  _sfx._on_request("a", Vector2.INF, 0.0, 1.0)
  _sfx._on_request("b", Vector2(10, 10), 0.0, 1.0)
  await await_idle_frame()

  assert_int(_count_playing(_sfx._pool_ui)).is_equal(1)
  assert_int(_count_playing(_sfx._pool_2d)).is_equal(1)


func test_stream_request_plays_on_2d_pool() -> void:
  # AudioStream直接指定でもプール経由で再生される
  var s := AudioStreamGenerator.new()

  _sfx._on_stream_request(s, Vector2(10, 10), 0.0, 1.0)
  await await_idle_frame()

  assert_int(_count_playing(_sfx._pool_2d)).is_equal(1)
  assert_bool(_sfx._pool_2d[0].stream == s or _sfx._pool_2d[1].stream == s).is_true()


func test_stream_request_same_frame_is_coalesced() -> void:
  # 同一ストリーム（同一インスタンス）を同フレームに2回 → 1音のみ
  var s := AudioStreamGenerator.new()

  _sfx._on_stream_request(s, Vector2(10, 10), 0.0, 1.0)
  _sfx._on_stream_request(s, Vector2(20, 20), 0.0, 1.0)
  await await_idle_frame()

  assert_int(_count_playing(_sfx._pool_2d)).is_equal(1)


func test_stream_request_different_streams_both_play() -> void:
  # 異なるストリームは同フレームでも両方鳴る
  var s1 := AudioStreamGenerator.new()
  var s2 := AudioStreamGenerator.new()

  _sfx._on_stream_request(s1, Vector2(10, 10), 0.0, 1.0)
  _sfx._on_stream_request(s2, Vector2(20, 20), 0.0, 1.0)
  await await_idle_frame()

  assert_int(_count_playing(_sfx._pool_2d)).is_equal(2)


func test_stream_request_null_is_ignored() -> void:
  # null ストリームは何もしない（エラーにならない）
  _sfx._on_stream_request(null, Vector2(10, 10), 0.0, 1.0)
  await await_idle_frame()

  assert_int(_count_playing(_sfx._pool_2d)).is_equal(0)


func test_pitch_zero_is_normalized_to_default() -> void:
  # pitch<=0 はセッターに拒否され前回値が残留するため、1.0 に正規化される
  # （例: pitch=2 の音の後に pitch=0 の音が同じプレイヤーを再利用するケース）
  _sfx._on_request("a", Vector2(10, 10), 0.0, 2.0)
  await await_millis(50)
  _sfx._pool_2d[0].stop()
  _sfx._pool_2d[1].stop()

  _sfx._on_request("b", Vector2(10, 10), 0.0, 0.0)
  await await_idle_frame()

  for p in _sfx._pool_2d:
    if p.playing:
      assert_float(p.pitch_scale).is_equal(1.0)
