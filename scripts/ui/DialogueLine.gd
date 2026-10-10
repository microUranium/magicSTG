extends Resource
class_name DialogueLine

@export var speaker_name: String = ""  # 表示名
@export var face_left: Texture2D = null  # 顔グラフィック（左側用）
@export var face_right: Texture2D = null  # 顔グラフィック（右側用）
@export_enum("left", "right", "both", "none") var speaker_side: String = "left"  # 表示位置
@export_enum("left", "right", "neutral") var box_direction: String = "left"  # フキダシの向き
@export_multiline var text: String = ""  # セリフ

## この行の表示に合わせて再生する BGM（未指定なら BGM は変えない）
@export var bgm: AudioStream = null
@export var bgm_volume_db: float = -10.0
@export var bgm_fade_in: float = 0.0

## この行の表示に合わせて鳴らす効果音（SFXカタログ名。空なら鳴らさない）
@export var sfx: String = ""
@export var sfx_volume_db: float = 0.0

## この行の表示に合わせた画面フラッシュの長さ（秒。0 なら光らせない）
@export var flash: float = 0.0
