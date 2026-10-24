extends PanelContainer
## ステージ進行状況（チャプター／ステージの解放・クリア）を自由に変更するデバッグパネル。
## デバッグビルドのステージ選択画面でのみ使用する（StageSelectController が生成する）。
## 変更は即座に StageDataManager へ反映し、セーブファイルにも保存する。

var _rows: VBoxContainer
var _chapter_checks := {}  # chapter_id → CheckBox(解放)
var _stage_unlock_checks := {}  # "chapter_id/stage_id" → CheckBox(解放)
var _stage_clear_checks := {}  # "chapter_id/stage_id" → CheckBox(クリア)


func _ready() -> void:
  var bg := StyleBoxFlat.new()
  bg.bg_color = Color(0, 0, 0, 0.85)
  bg.set_content_margin_all(12)
  add_theme_stylebox_override("panel", bg)

  var root := VBoxContainer.new()
  add_child(root)

  var header := HBoxContainer.new()
  root.add_child(header)
  var title := Label.new()
  title.text = "DEBUG: ステージ進行状況"
  title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  header.add_child(title)
  _add_button(header, "全解放", func(): StageDataManager.unlock_all())
  _add_button(header, "全クリア", func(): StageDataManager.unlock_all(true))
  _add_button(header, "リセット", func(): StageDataManager.reset_progress())

  var scroll := ScrollContainer.new()
  scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  root.add_child(scroll)
  _rows = VBoxContainer.new()
  _rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  scroll.add_child(_rows)

  _build_rows()
  StageDataManager.progress_changed.connect(_refresh)
  _refresh()


func _build_rows() -> void:
  for chapter in StageDataManager.get_all_chapters():
    var chapter_id := chapter.chapter_id
    var chapter_row := _add_row(chapter.chapter_name)
    _chapter_checks[chapter_id] = _add_check(
      chapter_row, "解放", func(on: bool): StageDataManager.set_chapter_unlocked(chapter_id, on)
    )

    for stage in chapter.stages:
      var stage_id := stage.stage_id
      var key := "%s/%s" % [chapter_id, stage_id]
      var stage_row := _add_row("    " + stage.stage_name)
      _stage_unlock_checks[key] = _add_check(
        stage_row,
        "解放",
        func(on: bool): StageDataManager.set_stage_unlocked(chapter_id, stage_id, on)
      )
      _stage_clear_checks[key] = _add_check(
        stage_row,
        "クリア",
        func(on: bool): StageDataManager.set_stage_cleared(chapter_id, stage_id, on)
      )


## 現在の進行状況をチェックボックスへ反映する（シグナルは発火させない）。
func _refresh() -> void:
  for chapter in StageDataManager.get_all_chapters():
    if _chapter_checks.has(chapter.chapter_id):
      _chapter_checks[chapter.chapter_id].set_pressed_no_signal(chapter.is_unlocked)
    for stage in chapter.stages:
      var key := "%s/%s" % [chapter.chapter_id, stage.stage_id]
      if _stage_unlock_checks.has(key):
        _stage_unlock_checks[key].set_pressed_no_signal(stage.is_unlocked)
        _stage_clear_checks[key].set_pressed_no_signal(
          StageDataManager.is_stage_cleared(chapter.chapter_id, stage.stage_id)
        )


func _add_row(label_text: String) -> HBoxContainer:
  var row := HBoxContainer.new()
  _rows.add_child(row)
  var label := Label.new()
  label.text = label_text
  label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(label)
  return row


func _add_check(row: HBoxContainer, text: String, on_toggled: Callable) -> CheckBox:
  var check := CheckBox.new()
  check.text = text
  check.toggled.connect(func(on: bool): _apply(on_toggled.bind(on)))
  row.add_child(check)
  return check


func _add_button(parent: Control, text: String, on_pressed: Callable) -> void:
  var button := Button.new()
  button.text = text
  button.pressed.connect(func(): _apply(on_pressed))
  parent.add_child(button)


## 変更を適用し、再起動後も残るよう即座にセーブする。
func _apply(change: Callable) -> void:
  change.call()
  SaveManager.save_game()
