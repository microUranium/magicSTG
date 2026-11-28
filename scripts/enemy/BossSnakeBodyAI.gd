extends EnemyAIBase
class_name BossSnakeBodyAI

var _parent_phase_idx: int = 0  # 現在のフェーズインデックス
var _destroy_attack_patterns: Array[AttackPattern] = []
var phase1_patterns: Array[AttackPattern] = []
var phase2_patterns: Array[AttackPattern] = []
var phase3_patterns: Array[AttackPattern] = []
var phase4_patterns: Array[AttackPattern] = []

## 本体の HP に応じて間隔が短くなる自機狙い弾（上の攻撃とは別のコアで、ずっと撃ち続ける）。
## 本体の HP の割合が down_to を上回っている間、その段階の間隔で撃つ。
## 間隔は min〜max の範囲で、節ごとに最初に1回だけランダムに決める
## 全節あわせた弾の数（毎秒）が、約0.8発から HP 30% までに約1.5発（段階ごとに約1.4倍）、
## そこから最後に約5発（段階ごとに約1.5倍）まで増えるように、
## 各段階の節の数（100→80%: 40→32、80→50%: 32→20、50→30%: 20→13、30% 以下: 13）から決めている
const AIMED_TIERS := [
  {"down_to": 0.8, "min": 40.0, "max": 50.0},  # 約0.8発/秒
  {"down_to": 0.5, "min": 20.0, "max": 27.0},  # 約1.1発/秒
  {"down_to": 0.3, "min": 9.5, "max": 12.5},  # 約1.5発/秒
  {"down_to": 0.2, "min": 5.0, "max": 6.6},  # 約2.2発/秒
  {"down_to": 0.1, "min": 3.3, "max": 4.5},  # 約3.3発/秒
  {"down_to": 0.0, "min": 2.2, "max": 3.0},  # 約5.0発/秒
]
const AIMED_TIER_DAMAGE := 2
const AIMED_TIER_SPEED := 500.0

var aimed_tier_patterns: Array[AttackPattern] = []  # AIMED_TIERS と同じ順
var _aimed_tier_core: UniversalAttackCore = null
var _aimed_tier_idx: int = -1


func _ready():
  _initialize_attack_patterns()
  super._ready()

  await get_tree().process_frame
  var head = get_parent().head_worm_boss
  head.connect("change_body_attack", Callable(self, "_setup_attack"))
  # HP に応じた自機狙い弾は、登場と会話が終わって戦闘（フェーズ2）が始まってから撃つ
  if _is_battle_started(head):
    _start_aimed_tier_attack(head)
  elif head.has_signal("battle_started"):
    head.battle_started.connect(_start_aimed_tier_attack.bind(head), CONNECT_ONE_SHOT)


func _initialize_attack_patterns():
  """攻撃パターンの初期化"""
  phase1_patterns.append(create_phase1_pattern())
  phase1_patterns.append(create_body_destroy_pattern())

  phase2_patterns.append(create_phase2_pattern())

  phase3_patterns.append(create_phase3_pattern())

  phase4_patterns.append(create_phase4_pattern())

  set_attack_patterns(phase1_patterns)


func _is_battle_started(head: Node) -> bool:
  return "ai" in head and is_instance_valid(head.ai) and head.ai._phase_idx >= 2


func _start_aimed_tier_attack(head: Node) -> void:
  """HP に応じて間隔が短くなる自機狙い弾を、専用のコアで撃ち始める"""
  for tier in AIMED_TIERS:
    aimed_tier_patterns.append(create_aimed_tier_pattern(randf_range(tier.min, tier.max)))
  _aimed_tier_core = attack_core_slot.add_core(core_scene)
  var hp_node = head.get_node_or_null("HpNode")
  if hp_node == null:
    _set_aimed_tier(0)
    _stagger_first_aimed_tier_shot()
    return
  hp_node.hp_changed.connect(_on_head_hp_changed)
  _on_head_hp_changed(hp_node.current_hp, hp_node.max_hp)
  _stagger_first_aimed_tier_shot()


func _stagger_first_aimed_tier_shot() -> void:
  """全節が同時に撃ち始めて波にならないよう、最初の1発までの待ち時間を 0〜間隔 の範囲でずらす"""
  if is_instance_valid(_aimed_tier_core):
    _aimed_tier_core.restart_cooldown(randf_range(0.0, _aimed_tier_core.cooldown_sec))


func _on_head_hp_changed(current_hp: int, max_hp: int) -> void:
  if max_hp <= 0:
    return
  _set_aimed_tier(aimed_tier_index_for(float(current_hp) / max_hp))


static func aimed_tier_index_for(hp_ratio: float) -> int:
  """HP の割合に当てはまる AIMED_TIERS の番号"""
  for i in AIMED_TIERS.size():
    if hp_ratio > AIMED_TIERS[i].down_to:
      return i
  return AIMED_TIERS.size() - 1


func _set_aimed_tier(idx: int) -> void:
  if idx == _aimed_tier_idx or not is_instance_valid(_aimed_tier_core):
    return
  var is_first := _aimed_tier_idx < 0
  _aimed_tier_idx = idx
  var interval := aimed_tier_patterns[idx].burst_delay
  _aimed_tier_core.attack_pattern = aimed_tier_patterns[idx]
  _aimed_tier_core.cooldown_sec = interval
  # 前の段階の長い待ちが残っていると、段階が変わってもしばらく撃たないので、
  # 残りの待ちが新しい間隔より長いときは、新しい間隔の中のランダムな長さに縮める
  if not is_first and _aimed_tier_core.get_cooldown_time_left() > interval:
    _aimed_tier_core.restart_cooldown(randf_range(0.0, interval))


func create_aimed_tier_pattern(interval: float) -> AttackPattern:
  """HP に応じた自機狙い弾（直進、弾速 AIMED_TIER_SPEED）。interval ごとに1発"""
  var pattern = AttackPatternFactory.create_single_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, AIMED_TIER_DAMAGE
  )
  pattern.target_group = "players"
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  pattern.bullet_speed = AIMED_TIER_SPEED
  pattern.burst_delay = interval
  pattern.bullet_lifetime = 5.0
  pattern.persist_offscreen = true

  # 見た目は白い鱗。大きさと当たり判定は、HP 30% 以下で撃つ鱗の弾と同じ
  var visual_config = BulletVisualConfig.new()
  visual_config.texture = preload("res://assets/gfx/sprites/bullet_snake_scale_white.png")
  visual_config.scale = 1
  visual_config.collision_radius = 8
  pattern.bullet_visual_config = visual_config
  return pattern


func _setup_attack(_phase_idx: int):
  """フェーズに応じた攻撃パターンを設定"""
  clear_all_pattern_cores()
  match _phase_idx:
    3:
      set_attack_patterns(phase2_patterns)
    4:
      set_attack_patterns(phase3_patterns)
    5:
      set_attack_patterns(phase4_patterns)
    _:
      set_attack_patterns(phase1_patterns)


func create_phase1_pattern() -> AttackPattern:
  """フェーズ1のパターンを作成"""
  var pattern = AttackPatternFactory.create_single_circle_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 1, 2
  )
  pattern.target_group = "players"
  pattern.direction_type = AttackPattern.DirectionType.TO_PLAYER
  pattern.burst_delay = 4

  var visual_config = BulletVisualConfig.new()
  visual_config.scale = 2
  visual_config.collision_radius = 16
  pattern.bullet_visual_config = visual_config

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 50
  movement_config.movement_type = BulletMovementConfig.MovementType.ACCELERATE
  movement_config.acceleration_rate = 100
  movement_config.min_speed = 250
  pattern.bullet_movement_config = movement_config

  return pattern


func create_body_destroy_pattern() -> AttackPattern:
  """胴体撃破時のパターンを作成"""
  var pattern = AttackPatternFactory.create_single_circle_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 12, 5
  )
  pattern.target_group = "players"
  pattern.direction_type = AttackPattern.DirectionType.RANDOM
  pattern.angle_spread = 360
  pattern.auto_start = false
  pattern.bullet_lifetime = 6.0
  pattern.persist_offscreen = true  # 画面外で壊れた節（尾）の弾も消さない（6秒で消える）

  var visual_config = BulletVisualConfig.new()
  visual_config.texture = preload("res://assets/gfx/sprites/bullet_snake_scale.png")
  visual_config.scale = 1
  visual_config.collision_radius = 8

  pattern.bullet_visual_config = visual_config

  var movement_config = BulletMovementConfig.new()
  movement_config.initial_speed = 500
  movement_config.movement_type = BulletMovementConfig.MovementType.DECELERATE
  movement_config.deceleration_rate = 500
  movement_config.min_speed = 50
  pattern.bullet_movement_config = movement_config

  return pattern


func create_phase2_pattern() -> AttackPattern:
  var pattern = AttackPatternFactory.create_single_shot(
    AttackPatternFactory.DEFAULT_BULLET_SCENE, 5
  )
  pattern.target_group = "players"
  pattern.direction_type = AttackPattern.DirectionType.RANDOM
  pattern.angle_spread = 360
  pattern.bullet_speed = 500
  pattern.burst_delay = 2 + 0.5 * randf_range(0, 1)

  var visual_config = BulletVisualConfig.new()
  visual_config.texture = preload("res://assets/gfx/sprites/bullet_snake_scale.png")
  visual_config.scale = 1
  visual_config.collision_radius = 8
  pattern.bullet_visual_config = visual_config

  return pattern


func create_phase3_pattern() -> AttackPattern:
  var pattern = create_phase2_pattern()
  pattern.bullet_count = 2
  pattern.burst_delay = 1.5 + 0.5 * randf_range(0, 1)

  return pattern


func create_phase4_pattern() -> AttackPattern:
  var pattern = create_phase2_pattern()
  pattern.burst_delay = 0.5 + 0.3 * randf_range(0, 1)

  return pattern


func fire_destroy_attack() -> void:
  """節が壊れたときの攻撃。BossSnake._destroy_segment から、節を削除する前に呼ばれる。
  （以前は tree_exiting で撃っていたが、そのときにはコアがツリーから外れていて撃てなかった）"""
  if is_instance_valid(attack_core_slot):
    attack_core_slot.trigger_all_cores()
