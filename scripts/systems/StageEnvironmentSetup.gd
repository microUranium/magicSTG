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


func setup_stage_background(stage_config: Dictionary) -> void:
  """ステージ背景のセットアップ"""
  var background_texture_path = stage_config.get("background_texture", "")
  if background_texture_path.is_empty():
    return

  var background = get_node_or_null("../Background")
  if background and background.has_method("set_background_texture"):
    var texture = load(background_texture_path)
    background.set_background_texture(texture)

    var scroll_speed = stage_config.get("scroll_speed", 100.0)
    if background.has_method("set_scroll_speed"):
      background.set_scroll_speed(scroll_speed)

    print_debug("StageEnvironmentSetup: Background texture set to: %s" % background_texture_path)
  else:
    push_warning(
      "StageEnvironmentSetup: Background node not found or missing set_background_texture method"
    )


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

  # Backgroundのチェック
  var background = get_node_or_null("../Background")
  if not background:
    push_warning("StageEnvironmentSetup: Background validation failed")
    is_valid = false
  return is_valid


func cleanup_environment() -> void:
  """環境のクリーンアップ（ステージ終了時）"""
  # 必要に応じてリソースのクリーンアップを実行
  print_debug("StageEnvironmentSetup: Environment cleanup completed")
