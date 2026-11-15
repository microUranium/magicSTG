extends BlessingBase

## 不屈の加護：致命的なダメージを受けた瞬間に自動で復活し、一定時間無敵になる。
## キー入力は不要だが、1ステージあたりの使用回数が決まっている（打消と同じくゲージに表示）。
##
## 発動判定は BlessingContainer が他の加護をすべて通した後に行うため、
## 防壁などが肩代わりできるダメージで回数を消費することはない。
##
## 道連（fortitude_michizure_damage_add）が付いていれば、発動時に画面内の敵全体へ
## その値のダメージを与える。ボスはフェーズを一度に複数飛ばさないよう、
## EnemyBase.take_burst_damage() で次のフェーズの境目までしか削らない。

signal revived(uses_remaining: int)

## 復活演出：星のパーティクルが外側から中心へ収束する（撃破時の飛散と逆の動き）
const REVIVE_PARTICLES_SCENE := preload("res://scenes/player/revive_particle_player.tscn")
## 道連の演出：ダメージを与えた敵から小さな星が飛び散る（撃破時の飛散を小さくしたもの）
const MICHIZURE_PARTICLES_SCENE := preload("res://scenes/enemy/michizure_particle.tscn")
const ENEMY_GROUP := "enemies"

var max_uses: int = 1  # 1ステージあたりの発動回数
var revive_hp_ratio: float = 0.5  # 復活時に回復する最大HPの割合
var invincible_sec: float = 2.0  # 復活直後の無敵時間
var michizure_damage: int = 0  # 道連：発動時に画面内の敵へ与えるダメージ（0 なら無効）

var _uses_remaining: int = 0
var _player_ref: Node2D


func _recalc_stats() -> void:
  max_uses = int(_proto.base_modifiers.get("max_uses", max_uses) + _sum_add("blessing_uses_add"))
  revive_hp_ratio = _proto.base_modifiers.get("fortitude_revive_hp_ratio", revive_hp_ratio)
  invincible_sec = _proto.base_modifiers.get("fortitude_invincible_sec", invincible_sec)
  invincible_sec *= 1.0 + _sum_pct("fortitude_invincible_pct")
  michizure_damage = int(round(_sum_add("fortitude_michizure_damage_add")))


func on_equip(player) -> void:
  _player_ref = player
  _recalc_stats()
  _uses_remaining = max_uses  # ステージ開始時に回数リセット
  init_gauge("durability", float(max_uses), float(_uses_remaining), _proto.display_name)


func get_uses_remaining() -> int:
  return _uses_remaining


func process_fatal_damage(player, _damage) -> bool:
  if _paused or _uses_remaining <= 0:
    return false
  if not is_instance_valid(player) or player.hp_node == null:
    return false

  if not _roll_free_use():  # 幸運が発動したら回数を消費しない
    _uses_remaining -= 1
    set_gauge(float(_uses_remaining))
    if _uses_remaining <= 0:
      set_gauge_style("durability_recovering")  # 使い切ったら無効表示へ

  _revive(player)
  _michizure()
  emit_signal("revived", _uses_remaining)
  return true


func _revive(player) -> void:
  # 復活後のHPは「最大HPの割合」で固定する（満タンから即死した場合は減る）
  var hp = player.hp_node
  # 致命傷は追加の体力（庇護）ごと削り切った扱い。残したままだと下の take_damage が
  # 追加の体力から先に減らしてしまい、通常の体力が復活時の割合まで下がらない。
  if hp.get("extra_hp") != null and hp.extra_hp > 0:
    hp.set_extra_hp(0)
  var revive_hp: int = maxi(1, int(round(hp.max_hp * revive_hp_ratio)))
  var diff: int = revive_hp - hp.current_hp
  if diff > 0:
    hp.heal(diff)
  elif diff < 0:
    hp.take_damage(-diff)

  if player.has_method("set_invincible"):
    player.set_invincible(invincible_sec)

  _play_revive_effects(player)


func _play_revive_effects(player) -> void:
  StageSignals.emit_request_hud_flash(0.3)
  StageSignals.emit_request_start_vibration()  # 画面を揺らす（撃破時と同じ処理）
  StageSignals.sfx_play_requested.emit("fortitude", player.global_position, 0.0, 1.0)
  _spawn_revive_particles(player.global_position)


func _spawn_revive_particles(pos: Vector2) -> void:
  var parent: Node = get_tree().current_scene if get_tree() else null
  if parent == null:
    return

  var particles: CPUParticles2D = REVIVE_PARTICLES_SCENE.instantiate()
  parent.add_child(particles)
  particles.global_position = pos
  particles.restart()

  # one_shot のため、寿命が尽きたら自動で片付ける（ステージ遷移で先に消えていても安全）
  var cleanup_timer := get_tree().create_timer(particles.lifetime + 0.2, false)
  cleanup_timer.timeout.connect(
    func():
      if is_instance_valid(particles):
        particles.queue_free()
  )


#---------------------------------------------------------------------
# 道連
#---------------------------------------------------------------------
func _michizure() -> void:
  """画面内の敵全体に michizure_damage のダメージを与え、それぞれから星を飛び散らせる"""
  if michizure_damage <= 0 or not is_inside_tree():
    return
  var damaged := {}  # 同じ相手に二重に当てないため（ヘビの胴体は頭に置き換える）
  for enemy in get_on_screen_enemies():
    _spawn_michizure_particles(enemy.global_position)
    var target := _resolve_damage_target(enemy)
    if target == null or damaged.has(target.get_instance_id()):
      continue
    damaged[target.get_instance_id()] = true
    if target.has_method("take_burst_damage"):
      target.take_burst_damage(michizure_damage)
    else:
      target.take_damage(michizure_damage)


func get_on_screen_enemies() -> Array[Node2D]:
  """敵グループのうち、画面内（PlayArea）にいるもの"""
  var result: Array[Node2D] = []
  var rect := PlayArea.get_play_rect()
  for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
    if not (node is Node2D) or node.is_queued_for_deletion():
      continue
    if rect.has_point(node.global_position):
      result.append(node)
  return result


func _resolve_damage_target(enemy: Node) -> Node:
  """ダメージを与える相手。ヘビの胴体（WormSegment）は受けたダメージを頭へ渡すので、頭に置き換える"""
  var head = enemy.get("head_worm_boss")
  if head != null:
    return head if is_instance_valid(head) else null
  return enemy if enemy.has_method("take_damage") else null


func _spawn_michizure_particles(pos: Vector2) -> void:
  var parent: Node = get_tree().current_scene
  if parent == null:
    return
  var particles: CPUParticles2D = MICHIZURE_PARTICLES_SCENE.instantiate()
  parent.add_child(particles)
  particles.global_position = pos
  particles.restart()
  var cleanup_timer := get_tree().create_timer(particles.lifetime + 0.2, false)
  cleanup_timer.timeout.connect(
    func():
      if is_instance_valid(particles):
        particles.queue_free()
  )
