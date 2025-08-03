# DialogueConverter統一変換システムの単体テスト
extends GdUnitTestSuite
class_name DialogueConverterTest

# テスト用の有効なテクスチャパス（実在確認済み）
const VALID_TEXTURE_PATH = "res://assets/gfx/sprites/felis_face_0.png"
const INVALID_TEXTURE_PATH = "res://nonexistent/texture.png"

# テスト用のGameDataRegistryモック状態管理
var _original_data_loaded: bool
var _original_dialogues: Dictionary = {}
var _mock_dialogue_data: Dictionary = {}
var _game_data_registry_exists: bool = false


func before_test():
  # 必要なクラスとリソースの存在確認
  _verify_test_prerequisites()

  # GameDataRegistryのモック化（既存メソッドを保存）
  _setup_game_data_registry_mock()

  # テスト用のDialogueデータを設定
  _setup_mock_dialogue_data()


func _verify_test_prerequisites():
  """テスト実行に必要な前提条件を確認"""
  # 必要なクラスの存在確認
  assert_that(DialogueLine).is_not_null().override_failure_message("DialogueLineクラスが見つかりません")
  assert_that(DialogueData).is_not_null().override_failure_message("DialogueDataクラスが見つかりません")
  assert_that(DialogueConverter).is_not_null().override_failure_message(
    "DialogueConverterクラスが見つかりません"
  )

  # GameDataRegistryの存在と必要メソッドの確認
  _game_data_registry_exists = (
    GameDataRegistry != null and GameDataRegistry.has_method("get_dialogue_data")
  )

  # テクスチャファイルの存在確認
  var texture_exists = ResourceLoader.exists(VALID_TEXTURE_PATH)
  if not texture_exists:
    push_warning("テスト用テクスチャファイルが見つかりません: %s" % VALID_TEXTURE_PATH)


func _setup_game_data_registry_mock():
  """GameDataRegistryの安全なモック化（既存テストパターンに準拠）"""
  if _game_data_registry_exists:
    # 元の状態を保存
    _original_data_loaded = GameDataRegistry._data_loaded

    _original_dialogues = (
      GameDataRegistry.dialogues.duplicate() if GameDataRegistry.dialogues else {}
    )

    # テスト用データを設定
    GameDataRegistry._data_loaded = true
    GameDataRegistry.dialogues = _mock_dialogue_data
  else:
    push_warning("GameDataRegistryが存在しないため、一部のテストをスキップします")


func after_test():
  # GameDataRegistryの安全な復元
  _restore_game_data_registry()

  # モックデータとリソースのクリア
  _cleanup_test_resources()


func _restore_game_data_registry():
  """GameDataRegistryの安全な復元（既存テストパターンに準拠）"""
  if _game_data_registry_exists:
    # 元の状態を復元
    GameDataRegistry._data_loaded = _original_data_loaded
    GameDataRegistry.dialogues = _original_dialogues.duplicate()


func _cleanup_test_resources():
  """テストリソースの完全クリア"""
  _mock_dialogue_data.clear()
  _original_dialogues.clear()
  _game_data_registry_exists = false


func _setup_mock_dialogue_data():
  """テスト用のモック会話データを設定"""
  _mock_dialogue_data = {
    "dialogues":
    {
      "test":
      {
        "valid_path":
        [
          {
            "speaker_name": "テストキャラ",
            "text": "テストメッセージ",
            "speaker_side": "left",
            "box_direction": "left",
            "face_left": VALID_TEXTURE_PATH,
            "face_right": null
          },
          {
            "speaker_name": "テストキャラ2",
            "text": "テストメッセージ2",
            "speaker_side": "right",
            "box_direction": "right",
            "face_left": null,
            "face_right": VALID_TEXTURE_PATH
          }
        ],
        "minimal": [{"speaker_name": "シンプル", "text": "最小構成"}],
        "invalid_texture":
        [{"speaker_name": "無効テクスチャ", "text": "無効なテクスチャパス", "face_left": INVALID_TEXTURE_PATH}]
      }
    }
  }
  # GameDataRegistryにモックデータをロード
  GameDataRegistry.load_stage_data(_mock_dialogue_data)


func test_convert_json_to_dialogue_lines_with_valid_data():
  """正常なJSONデータからDialogueLineへの変換テスト"""
  # Arrange
  var json_data = [
    {
      "speaker_name": "フェリス",
      "text": "こんにちは！",
      "speaker_side": "left",
      "box_direction": "left",
      "face_left": VALID_TEXTURE_PATH,
      "face_right": null
    },
    {
      "speaker_name": "ハーピー",
      "text": "こんばんは！",
      "speaker_side": "right",
      "box_direction": "right",
      "face_left": null,
      "face_right": VALID_TEXTURE_PATH
    }
  ]

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.size()).is_equal(2)

  # 最初の会話行
  var first_line = result[0] as DialogueLine
  assert_that(first_line).is_not_null()
  assert_that(first_line.speaker_name).is_equal("フェリス")
  assert_that(first_line.text).is_equal("こんにちは！")
  assert_that(first_line.speaker_side).is_equal("left")
  assert_that(first_line.box_direction).is_equal("left")
  assert_that(first_line.face_left).is_not_null()
  assert_that(first_line.face_right).is_null()

  # 2番目の会話行
  var second_line = result[1] as DialogueLine
  assert_that(second_line).is_not_null()
  assert_that(second_line.speaker_name).is_equal("ハーピー")
  assert_that(second_line.text).is_equal("こんばんは！")
  assert_that(second_line.speaker_side).is_equal("right")
  assert_that(second_line.box_direction).is_equal("right")
  assert_that(second_line.face_left).is_null()
  assert_that(second_line.face_right).is_not_null()


func test_convert_json_to_dialogue_lines_with_empty_array():
  """空配列の処理テスト"""
  # Arrange
  var json_data = []

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.size()).is_equal(0)


func test_convert_json_to_dialogue_lines_with_minimal_data():
  """最小構成データのテスト（デフォルト値の確認）"""
  # Arrange
  var json_data = [{"speaker_name": "テスト", "text": "最小メッセージ"}]

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.size()).is_equal(1)

  var line = result[0] as DialogueLine
  assert_that(line.speaker_name).is_equal("テスト")
  assert_that(line.text).is_equal("最小メッセージ")
  assert_that(line.speaker_side).is_equal("left")  # デフォルト値
  assert_that(line.box_direction).is_equal("left")  # デフォルト値
  assert_that(line.face_left).is_null()
  assert_that(line.face_right).is_null()


func test_convert_json_to_dialogue_lines_with_invalid_texture_path():
  """存在しないテクスチャパスの処理テスト"""
  # Arrange
  var json_data = [{"speaker_name": "テスト", "text": "無効テクスチャ", "face_left": INVALID_TEXTURE_PATH}]

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.size()).is_equal(1)

  var line = result[0] as DialogueLine
  assert_that(line.face_left).is_null()  # 無効なパスの場合はnullになる


func test_convert_json_to_dialogue_lines_with_null_texture_values():
  """nullテクスチャ値の処理テスト"""
  # Arrange
  var json_data = [
    {"speaker_name": "テスト", "text": "nullテクスチャ", "face_left": null, "face_right": null}
  ]

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.size()).is_equal(1)

  var line = result[0] as DialogueLine
  assert_that(line.face_left).is_null()
  assert_that(line.face_right).is_null()


func test_convert_json_to_dialogue_data_with_valid_data():
  """正常なJSONデータからDialogueDataへの変換テスト"""
  # Arrange
  var json_data = [{"speaker_name": "テスト", "text": "テストメッセージ"}]

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_data(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.lines).is_not_null()
  assert_that(result.lines.size()).is_equal(1)

  var line = result.lines[0] as DialogueLine
  assert_that(line.speaker_name).is_equal("テスト")
  assert_that(line.text).is_equal("テストメッセージ")


func test_convert_json_to_dialogue_data_with_empty_array():
  """空配列からDialogueDataへの変換テスト"""
  # Arrange
  var json_data = []

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_data(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.lines.size()).is_equal(0)


func test_get_dialogue_data_from_path_with_valid_path():
  """有効なパスでのDialogueData取得テスト"""
  # Arrange
  var dialogue_path = "test.valid_path"

  # Act
  var result = DialogueConverter.get_dialogue_data_from_path(dialogue_path)

  # Assert
  if _game_data_registry_exists:
    assert_that(result).is_not_null()
    assert_that(result.lines.size()).is_equal(2)

    var first_line = result.lines[0] as DialogueLine
    assert_that(first_line.speaker_name).is_equal("テストキャラ")
  else:
    # GameDataRegistryが存在しない場合はnullが返される
    assert_that(result).is_null()


func test_get_dialogue_data_from_path_with_invalid_path():
  """存在しないパスでのDialogueData取得テスト"""
  # Arrange
  var dialogue_path = "nonexistent.path"

  # Act
  var result = DialogueConverter.get_dialogue_data_from_path(dialogue_path)

  # Assert
  assert_that(result).is_null()


func test_get_dialogue_data_from_path_with_empty_string():
  """空文字列パスでのDialogueData取得テスト"""
  # Arrange
  var dialogue_path = ""

  # Act
  var result = DialogueConverter.get_dialogue_data_from_path(dialogue_path)

  # Assert
  assert_that(result).is_null()


func test_convert_json_to_dialogue_lines_with_malformed_data():
  """不正形式データの処理テスト（型安全性の確認）"""
  # Arrange - Dictionary以外の要素を含む配列
  var json_data = ["invalid_string", 123, null, {"speaker_name": "正常", "text": "正常メッセージ"}]

  # Act & Assert - エラーが発生しないことを確認
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)
  assert_that(result).is_not_null()
  # 不正な要素はスキップされ、正常な要素のみ処理される
  assert_that(result.size()).is_equal(1)  # Dictionary型の要素のみ処理される


func test_convert_json_to_dialogue_lines_with_missing_required_fields():
  """必須フィールド不足時の動作テスト"""
  # Arrange
  var json_data = [
    {
      # speaker_nameとtextが不足
      "speaker_side": "right"
    }
  ]

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.size()).is_equal(1)

  var line = result[0] as DialogueLine
  assert_that(line.speaker_name).is_equal("")  # デフォルト値
  assert_that(line.text).is_equal("")  # デフォルト値
  assert_that(line.speaker_side).is_equal("right")


func test_load_face_texture_edge_cases():
  """テクスチャ読み込みのエッジケース"""
  # Arrange
  var json_data = [
    {"speaker_name": "エッジケース", "text": "テスト", "face_left": "", "face_right": "invalid://path"}  # 空文字列  # 無効なスキーム
  ]

  # Act
  var result = DialogueConverter.convert_json_to_dialogue_lines(json_data)

  # Assert
  assert_that(result).is_not_null()
  assert_that(result.size()).is_equal(1)

  var line = result[0] as DialogueLine
  assert_that(line.face_left).is_null()
  assert_that(line.face_right).is_null()
