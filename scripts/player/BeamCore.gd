extends AttackCoreBase

@export var beam_duration: float = 2.0
@export var beam_scene: PackedScene

var beam_instance: Area2D = null
var _beam_duration_timer: SceneTreeTimer


func _ready():
  super._ready()

  # 汎用ゲージの初期化
  init_gauge("cooldown", 100, 0, "光線")


func _process(_delta: float) -> void:
  if _cool_timer and _cooling:
    var elapsed = _cool_timer.time_left
    set_gauge((cooldown_sec - elapsed) * 100 / cooldown_sec)  # 残り時間をゲージに反映
  elif _beam_duration_timer:
    var elapsed = _beam_duration_timer.time_left
    set_gauge((elapsed) * 100 / beam_duration)  # ビームの残り時間をゲージに反映


func trigger() -> void:  # ビームを打った後、すぐにクールダウンを開始せず、ビームの終了後にクールダウンを開始する
  if _cooling:
    return
  _do_fire()
  emit_signal("core_fired")


func _do_fire():
  if beam_scene:
    beam_instance = beam_scene.instantiate()
    get_tree().current_scene.add_child(beam_instance)

    if _owner_actor:
      beam_instance.global_position = _owner_actor.global_position  # 親はSpirit
    else:
      push_warning("BeamCore: Owner actor is not set. Using default position.")

    # Beam.gd に desired_length プロパティがある場合設定
    beam_instance.desired_length = 800.0  # 必要に応じて変更

    # initialize() でowner_nodeを直接渡す
    if beam_instance.has_method("initialize"):
      beam_instance.initialize(_owner_actor)

    # body_entered シグナル接続（ビームが Area2D である前提）
    beam_instance.connect("body_entered", Callable(self, "_on_beam_body_entered"))

    _beam_duration_timer = get_tree().create_timer(beam_duration)

    # 一定時間後にビームを削除
    await _beam_duration_timer.timeout
    if is_instance_valid(beam_instance):
      beam_instance.queue_free()
      _start_cooldown()


func _on_beam_body_entered(_body):
  # damage_enemy(body)
  pass
