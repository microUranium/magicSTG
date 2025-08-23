shader_type canvas_item;
render_mode blend_mix;

uniform float fade_progress : hint_range(0.0, 1.0) = 0.0;
uniform float glow_intensity : hint_range(0.0, 3.0) = 2.0;
uniform vec3 warning_color : source_color = vec3(1.0, 0.2, 0.2);

void fragment() {
	// 中心からの距離に基づくグラデーション
	float center_distance = abs(UV.y - 0.5) * 2.0;
	float glow_falloff = 1.0 - pow(center_distance, 0.8);
	
	// フェードイン（警告時間全体でゆっくりと）
	float alpha = fade_progress * glow_falloff;
	
	// 加算ブレンド用に輝度を調整
	vec3 final_color = warning_color * glow_intensity;
	
	COLOR = vec4(final_color, alpha);
}