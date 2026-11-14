// 時界の加護：背景の色を反転する（背景のすぐ上の CanvasLayer に置いた ColorRect に使う）。
// その時点までに描かれた画面（＝背景だけ）を読み取って描き直すので、自機・敵・弾は反転しない。
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float invert_outside : hint_range(0.0, 1.0) = 0.0; // 結界の外側の反転の強さ
uniform float invert_inside : hint_range(0.0, 1.0) = 0.0; // 結界の内側の反転の強さ
uniform float flash : hint_range(0.0, 1.0) = 0.0; // 結界の内側を白く光らせる強さ（終了時）
uniform vec2 center_uv = vec2(0.5, 0.5); // 自機の画面上の位置（0〜1）
uniform vec2 view_size = vec2(1152.0, 960.0); // ゲーム画面の大きさ（px）
uniform float radius_px = 200.0; // 結界の半径（px）
uniform float edge_px = 16.0; // 境界をぼかす幅（px）

void fragment() {
  vec3 col = texture(screen_tex, SCREEN_UV).rgb;
  float dist = length((SCREEN_UV - center_uv) * view_size);
  float inside = 1.0 - smoothstep(radius_px - edge_px, radius_px, dist);
  float amount = mix(invert_outside, invert_inside, inside);
  col = mix(col, vec3(1.0) - col, amount);
  col = mix(col, vec3(1.0), flash * inside);
  COLOR = vec4(col, 1.0);
}
