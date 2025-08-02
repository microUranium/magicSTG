extends Node
class_name StageEnvironmentSetup

#---------------------------------------------------------------------
# Public Interface
#---------------------------------------------------------------------


func setup_bullet_layer() -> void:
  """BulletLayerを見つけてTargetServiceに設定"""
  var bullet_layer = get_node_or_null("../BulletLayer")
  if bullet_layer:
    TargetService.set_bullet_parent(bullet_layer)
    print_debug("StageEnvironmentSetup: BulletLayer initialized: %s" % bullet_layer.name)
  else:
    push_warning("StageEnvironmentSetup: BulletLayer not found. Bullets will use fallback parent.")


func initialize(parent: Node) -> bool:
  """Component Registryからの初期化"""
  setup_stage_environment()
  return true


func setup_stage_environment() -> void:
  """ステージ環境全体のセットアップ"""
  setup_bullet_layer()
  # 将来的に他の環境設定もここに追加
  _setup_additional_services()


#---------------------------------------------------------------------
# Private Methods
#---------------------------------------------------------------------


func _setup_additional_services() -> void:
  """追加のサービス設定（将来の拡張用）"""
  # 例: パーティクルシステムの初期化
  # 例: カメラシステムの設定
  # 例: エフェクトマネージャーの初期化
  pass


#---------------------------------------------------------------------
# Utility Methods
#---------------------------------------------------------------------


func validate_environment() -> bool:
  """環境設定が正しく完了しているかチェック"""
  var is_valid := true

  # BulletLayerのチェック
  var bullet_layer = get_node_or_null("../BulletLayer")
  if not bullet_layer:
    push_warning("StageEnvironmentSetup: BulletLayer validation failed")
    is_valid = false

    # TargetServiceのチェック
  if not TargetService.has_bullet_parent():
    push_warning("StageEnvironmentSetup: TargetService validation failed")
    is_valid = false
  return is_valid


func cleanup_environment() -> void:
  """環境のクリーンアップ（ステージ終了時）"""
  # 必要に応じてリソースのクリーンアップを実行
  print_debug("StageEnvironmentSetup: Environment cleanup completed")
