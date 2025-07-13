@tool
extends Resource
class_name EnemyPatternResource

@export var move_to:Vector2 = Vector2.ZERO
@export var move_time:float = 1.0
@export var core_to_enable:String = ""   # AttackCoreSlot 内子ノード名
@export var core_duration:float = 3.0
@export var dialogue:DialogueData = null # 行動開始時に挟む会話

func start(enemy:Node2D, _ai:Node, finished_cb:Callable):
  # 1. optional dialogue
  if dialogue:
    print_debug("finished_cb :", finished_cb.get_object(), " - ", finished_cb.get_method())
    StageSignals.emit_request_dialogue(dialogue, finished_cb)
    return   # dialogueが終わったら同コールバックで再開

  # 2. move tween
  var tw = enemy.create_tween()
  tw.tween_property(enemy, "global_position", move_to, move_time)
  print_debug("EnemyPatternResource: move_to ", move_to, " time ", move_time)
  if core_to_enable.is_empty():
    tw.tween_callback(finished_cb)  # Coreを有効化しない場合はそのままコールバック
  else:
    tw.tween_callback(func(): _enable_core_then_wait(enemy, finished_cb))
  return tw


func _enable_core_then_wait(enemy:Node2D, finished_cb:Callable):
  var slot = enemy.slot.get_node_or_null(core_to_enable)
  if slot:
    slot.set_phased(true)          # 任意：Core 側で発射ON/OFF切替関数
  enemy.get_tree().create_timer(core_duration).timeout.connect(func():
    if slot:
      slot.set_phased(false)
    finished_cb.call()
  )
