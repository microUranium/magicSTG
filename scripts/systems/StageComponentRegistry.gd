extends RefCounted
class_name StageComponentRegistry

signal component_registered(name: String)
signal component_initialized(name: String)
signal component_failed(name: String, error: String)
signal all_components_ready

#---------------------------------------------------------------------
# Component Status Management
#---------------------------------------------------------------------
enum ComponentStatus { UNREGISTERED, REGISTERED, INITIALIZING, READY, FAILED }


class ComponentInfo:
  var name: String
  var path: NodePath
  var instance: Node
  var expected_type: GDScript
  var status: ComponentStatus = ComponentStatus.UNREGISTERED
  var dependencies: Array[String] = []
  var initialization_priority: int = 0
  var error_message: String = ""

  func _init(component_name: String, node_path: NodePath, type: GDScript):
    name = component_name
    path = node_path
    expected_type = type


#---------------------------------------------------------------------
# Registry Data
#---------------------------------------------------------------------
var _components: Dictionary = {}  # String -> ComponentInfo
var _parent_node: Node
var _initialization_order: Array[String] = []

#---------------------------------------------------------------------
# Public Interface
#---------------------------------------------------------------------


func initialize(parent: Node) -> void:
  """レジストリを初期化"""
  _parent_node = parent


func register_component(name: String, path: NodePath, type: GDScript, priority: int = 0) -> bool:
  """コンポーネントを登録"""
  if name in _components:
    push_warning("StageComponentRegistry: Component '%s' already registered" % name)
    return false
  var info = ComponentInfo.new(name, path, type)
  info.initialization_priority = priority
  info.status = ComponentStatus.REGISTERED

  _components[name] = info
  component_registered.emit(name)
  return true


func add_dependency(component: String, depends_on: String) -> bool:
  """依存関係を追加"""
  if not component in _components or not depends_on in _components:
    push_error("StageComponentRegistry: Cannot add dependency, component not found")
    return false
  var info = _components[component] as ComponentInfo
  if not depends_on in info.dependencies:
    info.dependencies.append(depends_on)
  return true


func initialize_all_components() -> bool:
  """すべてのコンポーネントを初期化"""
  if not _parent_node:
    push_error("StageComponentRegistry: Parent node not set")
    return false
  _calculate_initialization_order()

  for component_name in _initialization_order:
    if not _initialize_component(component_name):
      return false
  _connect_component_signals()
  all_components_ready.emit()
  return true


func get_component(name: String) -> Node:
  """コンポーネントインスタンスを取得"""
  if name in _components:
    var info = _components[name] as ComponentInfo
    if info.status == ComponentStatus.READY:
      return info.instance
  return null


func get_component_status(name: String) -> ComponentStatus:
  """コンポーネントの状態を取得"""
  if name in _components:
    return (_components[name] as ComponentInfo).status
  return ComponentStatus.UNREGISTERED


func is_all_components_ready() -> bool:
  """すべてのコンポーネントが準備完了かチェック"""
  for component_name in _components:
    var info = _components[component_name] as ComponentInfo
    if info.status != ComponentStatus.READY:
      return false
  return true


func get_failed_components() -> Array[String]:
  """失敗したコンポーネントのリストを取得"""
  var failed = []
  for component_name in _components:
    var info = _components[component_name] as ComponentInfo
    if info.status == ComponentStatus.FAILED:
      failed.append(component_name)
  return failed


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------


func _calculate_initialization_order() -> void:
  """依存関係を考慮した初期化順序を計算"""
  _initialization_order.clear()
  var remaining = _components.keys()
  var resolved = []

  # 優先度でソート
  remaining.sort_custom(
    func(a, b):
      return (
        (_components[a] as ComponentInfo).initialization_priority
        < (_components[b] as ComponentInfo).initialization_priority
      )

      # 依存関係解決

      # 依存関係チェック
  )

  # 依存関係解決
  while remaining.size() > 0:
    var progress_made = false
    var i = 0

    while i < remaining.size():
      var component_name = remaining[i]
      var info = _components[component_name] as ComponentInfo
      var can_initialize = true

      # 依存関係チェック
      for dependency in info.dependencies:
        if dependency not in resolved:
          can_initialize = false
          break
      if can_initialize:
        _initialization_order.append(component_name)
        resolved.append(component_name)
        remaining.remove_at(i)
        progress_made = true
      else:
        i += 1
    if not progress_made:
      push_error(
        "StageComponentRegistry: Circular dependency detected in components: %s" % remaining
      )
      break


func _initialize_component(name: String) -> bool:
  """個別コンポーネントを初期化"""
  if not name in _components:
    return false

    # NodePath が空の場合はスキップ（オプショナルコンポーネント）

    # インスタンス取得

    # 型チェック（カスタムクラスの場合はスキップ）

    # カスタムクラスの場合はscriptでチェック

    # コンポーネント固有の初期化
  var info = _components[name] as ComponentInfo
  info.status = ComponentStatus.INITIALIZING

  # NodePath が空の場合はスキップ（オプショナルコンポーネント）
  if info.path == NodePath():
    info.status = ComponentStatus.READY
    return true

    # インスタンス取得

    # 型チェック（カスタムクラスの場合はスキップ）

    # カスタムクラスの場合はscriptでチェック

    # コンポーネント固有の初期化
  info.instance = _parent_node.get_node_or_null(info.path)
  if not info.instance:
    info.error_message = "Node not found at path: %s" % info.path
    info.status = ComponentStatus.FAILED
    component_failed.emit(name, info.error_message)
    push_error("StageComponentRegistry: %s" % info.error_message)
    return false

    # 型チェック（カスタムクラスの場合はスキップ）

    # カスタムクラスの場合はscriptでチェック

    # コンポーネント固有の初期化
  var expected_class_name = info.expected_type.get_global_name()
  if expected_class_name and not info.instance.is_class(expected_class_name):
    # カスタムクラスの場合はscriptでチェック
    var script_path = info.instance.get_script()
    if script_path:
      var script_class_name = script_path.get_global_name()
      if script_class_name != expected_class_name:
        info.error_message = (
          "Type mismatch: expected %s, got %s (script: %s)"
          % [expected_class_name, info.instance.get_class(), script_class_name]
        )
        info.status = ComponentStatus.FAILED
        component_failed.emit(name, info.error_message)
        push_error("StageComponentRegistry: %s" % info.error_message)
        return false

      # コンポーネント固有の初期化
    else:
      pass  # カスタムクラスで型チェックをスキップ

      # コンポーネント固有の初期化
  if info.instance.has_method("initialize"):
    if not info.instance.initialize(_parent_node):
      info.error_message = "Component initialization failed"
      info.status = ComponentStatus.FAILED
      component_failed.emit(name, info.error_message)
      return false
  info.status = ComponentStatus.READY
  component_initialized.emit(name)
  return true


func _connect_component_signals() -> void:
  """コンポーネント間のシグナル接続"""
  # UI Controller の Ready プロンプト完了シグナル
  var ui_controller = get_component("ui")
  if ui_controller and ui_controller.has_signal("ready_prompt_finished"):
    if not ui_controller.ready_prompt_finished.is_connected(_parent_node._setup_stage_environment):
      ui_controller.ready_prompt_finished.connect(_parent_node._setup_stage_environment)

      # Lifecycle Controller のシグナル接続
  var lifecycle_controller = get_component("lifecycle")
  if lifecycle_controller:
    if (
      lifecycle_controller.has_signal("stage_cleared")
      and not lifecycle_controller.stage_cleared.is_connected(
        _parent_node._handle_lifecycle_stage_cleared
      )
    ):
      lifecycle_controller.stage_cleared.connect(_parent_node._handle_lifecycle_stage_cleared)
    if (
      lifecycle_controller.has_signal("stage_failed")
      and not lifecycle_controller.stage_failed.is_connected(
        _parent_node._handle_lifecycle_stage_failed
      )
    ):
      lifecycle_controller.stage_failed.connect(_parent_node._handle_lifecycle_stage_failed)


#---------------------------------------------------------------------
# Debug & Utility
#---------------------------------------------------------------------


func get_registry_status() -> Dictionary:
  """レジストリの状態をデバッグ用に取得"""
  var status = {}
  for component_name in _components:
    var info = _components[component_name] as ComponentInfo
    status[component_name] = {
      "status": ComponentStatus.keys()[info.status],
      "path": str(info.path),
      "dependencies": info.dependencies,
      "error": info.error_message
    }
  return status


func print_registry_status() -> void:
  """レジストリの状態をコンソールに出力"""
  print_debug("=== StageComponentRegistry Status ===")
  for component_name in _components:
    var info = _components[component_name] as ComponentInfo
    var status_text = (
      "%s: %s (deps: %s)" % [component_name, ComponentStatus.keys()[info.status], info.dependencies]
    )
    if info.status == ComponentStatus.FAILED and not info.error_message.is_empty():
      status_text += " - Error: " + info.error_message
    print_debug(status_text)
  print_debug("Initialization order: " + str(_initialization_order))
