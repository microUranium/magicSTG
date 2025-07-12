@tool
extends Resource
class_name SFXCatalog

# 例: {"explosion": [stream1, stream2], "ui_click": [stream3]}
@export var table :Dictionary[String, AudioStream]