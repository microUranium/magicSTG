extends Control
class_name GaugeManager

## ----------------------------------------
##  HUD 上に “汎用ゲージ” を並べるマネージャ
## ----------------------------------------

@export_node_path("Control") var container_path : NodePath        # ゲージを並べるコンテナ
var _gauge_scene : PackedScene = preload("res://assets/HUD/generic_gauge/generic_gauge.tscn")
var _provider_map : Dictionary = {}        # provider(Node) -> gauge(Control)

@onready var _container : Control = (
  self if container_path == NodePath() else get_node(container_path)
)

# -----------------------------------------------------------------
func _ready() -> void:
  call_deferred("_scan_existing_providers")
  get_tree().connect("node_added", Callable(self, "_on_node_added"))
  # Provider 自身が emit する gauge_unregistered で削除を受け持つ

# -----------------------------------------------------------------
# 既存 Provider を登録
func _scan_existing_providers() -> void:
  for p in get_tree().get_nodes_in_group("gauge_providers"):
    _register_provider(p)

# 動的追加
func _on_node_added(node : Node) -> void:
  if node.is_in_group("gauge_providers"):
    _register_provider(node)

# -----------------------------------------------------------------
# Provider を HUD にひも付け
func _register_provider(provider : Node) -> void:
  if provider in _provider_map:       # 二重登録防止
    return

  if not provider.show_on_hud:          # HUD 対象外なら早期 return
    return

  # GenericGauge を生成
  var gauge : Control = _gauge_scene.instantiate()
  if gauge.has_method("init_from_provider"):
    gauge.call("init_from_provider", provider)
  _container.add_child(gauge)
  _provider_map[provider] = gauge

  # Provider からの通知を横流し
  provider.connect("gauge_changed",       Callable(self, "_on_provider_value").bind(provider))
  provider.connect("gauge_style_changed", Callable(self, "_on_provider_style").bind(provider))
  provider.connect("gauge_unregistered",  Callable(self, "_on_provider_unregistered").bind(provider))

# -----------------------------------------------------------------
# Provider → Gauge 値更新
func _on_provider_value(current : float, max_value : float, provider : Node) -> void:
  var gauge : Control = _provider_map.get(provider)
  if gauge and gauge.has_method("update_value"):
    gauge.call("update_value", current, max_value)

# Provider → Gauge スタイル変更
func _on_provider_style(style : String, provider : Node) -> void:
  var gauge : Control = _provider_map.get(provider)
  if gauge and gauge.has_method("update_style"):
    gauge.call("update_style", style)

# Provider 消滅／解除
func _on_provider_unregistered(provider : Node) -> void:
  var gauge : Control = _provider_map.get(provider)
  if gauge:
    _provider_map.erase(provider)
    gauge.queue_free()
