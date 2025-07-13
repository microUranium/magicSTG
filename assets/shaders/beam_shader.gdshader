shader_type canvas_item;

uniform int frame_count = 3; // コマ数
uniform float fps = 12.0; // アニメーション速度

void fragment() {
  // 現在のフレーム番号を算出
  int frame = int(mod(TIME * fps, float(frame_count)));

  // 各フレームのUVオフセットを計算
  vec2 uv = UV;
  uv.x = uv.x / float(frame_count) + float(frame) / float(frame_count);

  COLOR = texture(TEXTURE, uv) * texture(TEXTURE, uv).a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
