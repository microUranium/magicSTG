extends Node
class_name DialogueConverter
## JSON形式の会話データをDialogueLine配列やDialogueDataオブジェクトに変換するユーティリティクラス


## JSON配列をDialogueLine配列に変換
static func convert_json_to_dialogue_lines(json_data: Array) -> Array[DialogueLine]:
  var dialogue_lines: Array[DialogueLine] = []

  # null安全性チェック
  if json_data == null:
    push_warning("DialogueConverter: json_data is null, returning empty array")
    return dialogue_lines

  for line_data in json_data:
    # 型安全性チェック：line_dataがDictionaryかどうか確認
    if not line_data is Dictionary:
      push_warning("DialogueConverter: Invalid line_data type (expected Dictionary), skipping")
      continue

    var line := DialogueLine.new()
    var dict_data = line_data as Dictionary

    line.speaker_name = dict_data.get("speaker_name", "")
    line.text = dict_data.get("text", "")
    line.speaker_side = dict_data.get("speaker_side", "left")
    line.box_direction = dict_data.get("box_direction", "left")

    # テクスチャ読み込み（エラーハンドリング強化）
    _load_face_texture(line, dict_data, "face_left")
    _load_face_texture(line, dict_data, "face_right")

    dialogue_lines.append(line)
  return dialogue_lines


## JSON配列からDialogueDataオブジェクトを生成
static func convert_json_to_dialogue_data(json_data: Array) -> DialogueData:
  # null安全性チェック
  if json_data == null:
    push_warning("DialogueConverter: json_data is null for convert_json_to_dialogue_data")
    json_data = []  # 空配列で処理続行

  var dialogue_data := DialogueData.new()
  dialogue_data.lines = convert_json_to_dialogue_lines(json_data)
  return dialogue_data


## GameDataRegistryからパス指定でDialogueDataを取得・変換
static func get_dialogue_data_from_path(dialogue_path: String) -> DialogueData:
  print_debug("DialogueConverter: get_dialogue_data_from_path called with path: ", dialogue_path)
  # null/空文字列チェック
  if dialogue_path == null or dialogue_path.is_empty():
    push_warning("DialogueConverter: Invalid dialogue_path (null or empty)")
    return null

  print_debug(
    "DialogueConverter: Fetching dialogue data from GameDataRegistry for path: ", dialogue_path
  )
  # GameDataRegistryの存在確認
  if not GameDataRegistry or not GameDataRegistry.has_method("get_dialogue_data"):
    push_error(
      "DialogueConverter: GameDataRegistry not available or missing get_dialogue_data method"
    )
    return null

  print_debug("DialogueConverter: Fetching dialogue data from GameDataRegistry")
  var json_data = GameDataRegistry.get_dialogue_data(dialogue_path)
  if json_data == null or json_data.is_empty():
    push_warning("DialogueConverter: Dialogue path '%s' not found" % dialogue_path)
    return null

  print_debug("DialogueConverter: Converting JSON data to DialogueData")
  return convert_json_to_dialogue_data(json_data)


## 内部ヘルパー: テクスチャ読み込み処理
static func _load_face_texture(
  line: DialogueLine, line_data: Dictionary, texture_key: String
) -> void:
  # null安全性チェック
  if line == null:
    push_error("DialogueConverter: line is null in _load_face_texture")
    return

  if line_data == null:
    push_warning("DialogueConverter: line_data is null in _load_face_texture")
    return

  if texture_key == null or texture_key.is_empty():
    push_warning("DialogueConverter: texture_key is invalid in _load_face_texture")
    return

  var texture_path = line_data.get(texture_key, null)

  # テクスチャパスの妥当性チェック
  if texture_path == null or not texture_path is String or texture_path.is_empty():
    return  # 無効なパスは静かにスキップ

  # リソースの存在確認（load前にチェック）
  if not ResourceLoader.exists(texture_path):
    push_warning("DialogueConverter: Texture file does not exist: %s" % texture_path)
    return

  # テクスチャ読み込み（try-catchスタイルエラーハンドリング）
  var texture = load(texture_path) as Texture2D
  if texture != null:
    # texture_keyの妥当性チェックと設定
    match texture_key:
      "face_left":
        line.face_left = texture
      "face_right":
        line.face_right = texture
      _:
        push_warning("DialogueConverter: Unknown texture_key: %s" % texture_key)
  else:
    push_warning("DialogueConverter: Failed to load texture or invalid format: %s" % texture_path)
