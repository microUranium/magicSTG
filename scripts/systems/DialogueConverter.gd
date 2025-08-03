extends Node
class_name DialogueConverter
## JSON形式の会話データをDialogueLine配列やDialogueDataオブジェクトに変換するユーティリティクラス


## JSON配列をDialogueLine配列に変換
static func convert_json_to_dialogue_lines(json_data: Array) -> Array[DialogueLine]:
  var dialogue_lines: Array[DialogueLine] = []

  for line_data in json_data:
    var line := DialogueLine.new()
    line.speaker_name = line_data.get("speaker_name", "")
    line.text = line_data.get("text", "")
    line.speaker_side = line_data.get("speaker_side", "left")
    line.box_direction = line_data.get("box_direction", "left")

    # テクスチャ読み込み
    _load_face_texture(line, line_data, "face_left")
    _load_face_texture(line, line_data, "face_right")

    dialogue_lines.append(line)
  return dialogue_lines


## JSON配列からDialogueDataオブジェクトを生成
static func convert_json_to_dialogue_data(json_data: Array) -> DialogueData:
  var dialogue_data := DialogueData.new()
  dialogue_data.lines = convert_json_to_dialogue_lines(json_data)
  return dialogue_data


## GameDataRegistryからパス指定でDialogueDataを取得・変換
static func get_dialogue_data_from_path(dialogue_path: String) -> DialogueData:
  var json_data = GameDataRegistry.get_dialogue_data(dialogue_path)
  if json_data.is_empty():
    push_warning("DialogueConverter: Dialogue path '%s' not found" % dialogue_path)
    return null
  return convert_json_to_dialogue_data(json_data)


## 内部ヘルパー: テクスチャ読み込み処理
static func _load_face_texture(
  line: DialogueLine, line_data: Dictionary, texture_key: String
) -> void:
  var texture_path = line_data.get(texture_key, null)
  if texture_path and texture_path != null:
    var texture = load(texture_path) as Texture2D
    if texture:
      if texture_key == "face_left":
        line.face_left = texture
      elif texture_key == "face_right":
        line.face_right = texture
    else:
      push_warning("DialogueConverter: Failed to load texture: %s" % texture_path)
