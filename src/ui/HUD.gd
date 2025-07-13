extends CanvasLayer

@export var player_path: NodePath

func _ready():
  var player := get_node(player_path)
  if player == null:
    push_warning("PlayerHUD: Player not found")
    return

  var hp_node := player.get_node("HpNode")                     # 子ノード名が 'HpNode' 前提
  if hp_node == null:
    push_warning("PlayerHUD: HPNode not found")
    return

  # Signal 受信 → HPBar 更新
  hp_node.connect("hp_changed", Callable(self, "_on_hp_changed"))

  # 初期表示も更新
  _on_hp_changed(hp_node.current_hp, hp_node.max_hp)

func _on_hp_changed(current_hp: int, max_hp: int):
  $HPBar.update_hp(current_hp, max_hp)