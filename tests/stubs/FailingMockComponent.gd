# 初期化が失敗するテスト用のモックコンポーネント
extends Node
class_name FailingMockComponent


# 初期化メソッド（必ず失敗する）
func initialize(parent: Node) -> bool:
  """必ず失敗する初期化処理"""
  return false


# テスト用の状態管理
var _failure_reason: String = "Mock initialization failure"


func get_failure_reason() -> String:
  """失敗理由の取得"""
  return _failure_reason


func set_failure_reason(reason: String):
  """失敗理由の設定"""
  _failure_reason = reason
