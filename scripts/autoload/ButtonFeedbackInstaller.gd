extends Node

## シーンに追加されたすべての BaseButton に ButtonFeedback（押下アニメーション＋クリック音）を自動で付ける。
## 次のボタンには付けない:
## - 独自設定の ButtonFeedback が既に付いているボタン（StageButton など）
## - メタデータ "no_button_feedback" が true のボタン

const OPT_OUT_META := &"no_button_feedback"


func _ready() -> void:
  get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
  if node is BaseButton:
    # ツリーへの追加処理中は子を追加できない。また、シーン側のスクリプトが _ready で
    # 独自の ButtonFeedback を付ける場合があるため、それらが済んでから判定する
    _attach_if_needed.call_deferred(node)


func _attach_if_needed(node: Object) -> void:
  if not is_instance_valid(node):
    return
  var button := node as BaseButton
  if not button or not button.is_inside_tree():
    return
  if button.get_meta(OPT_OUT_META, false):
    return
  if ButtonFeedback.find_on(button):
    return
  ButtonFeedback.attach(button)
