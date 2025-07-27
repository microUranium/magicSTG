extends Node

signal request_dialogue(dialogue_data, finished_cb)
signal request_hud_flash(fade_duration)
signal request_change_background_scroll_speed(new_speed: float, change_time: float)
signal request_start_vibration
signal destroy_bullet

## ───── BGM 系シグナル ─────
signal bgm_play_requested(stream: AudioStream, fade_time: float)
signal bgm_stop_requested(fade_time: float)

## ───── SFX 系シグナル ─────
signal sfx_play_requested(name: String, pos: Vector2, vol_db: float, pitch: float)  # カタログ名  # INF なら UI / 非 2D


func emit_request_dialogue(dd, cb):
  emit_signal("request_dialogue", dd, cb)


func emit_request_hud_flash(fade_duration):
  emit_signal("request_hud_flash", fade_duration)


func emit_request_change_background_scroll_speed(new_speed: float, change_time: float):
  emit_signal("request_change_background_scroll_speed", new_speed, change_time)


func emit_request_start_vibration():
  emit_signal("request_start_vibration")


func emit_destroy_bullet():
  emit_signal("destroy_bullet")


func emit_bgm_play_requested(stream: AudioStream, fade_time: float, maxdb: float):
  emit_signal("bgm_play_requested", stream, fade_time, maxdb)


func emit_bgm_stop_requested(fade_time: float):
  emit_signal("bgm_stop_requested", fade_time)
