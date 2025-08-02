# テスト用のモックコンポーネント
extends Node
class_name MockComponent


# 初期化メソッド（Component Registryが呼び出す）
func initialize(parent: Node) -> bool:
  """コンポーネント初期化のモック"""
  return true


# テスト用の状態管理
var _is_initialized: bool = false
var _initialization_count: int = 0


func set_initialized(value: bool):
  """初期化状態の設定"""
  _is_initialized = value


func is_initialized() -> bool:
  """初期化状態の取得"""
  return _is_initialized


func get_initialization_count() -> int:
  """初期化回数の取得"""
  return _initialization_count


func mock_initialize(parent: Node) -> bool:
  """モック初期化処理"""
  _initialization_count += 1
  _is_initialized = true
  return true


# テスト用のシグナル
signal mock_signal_fired(data)


func emit_mock_signal(data = null):
  """テスト用シグナル発火"""
  mock_signal_fired.emit(data)
