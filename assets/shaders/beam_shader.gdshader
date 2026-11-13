shader_type canvas_item;

uniform int frame_count = 3; // コマ数
uniform float fps = 12.0; // アニメーション速度
// コマ送りに使う経過時間。0 以上ならこちらを使い、負なら TIME を使う。
// TIME はポーズ中も進むため、ポーズで止めたいビームはスクリプトから渡す（UniversalBeam）。
uniform float anim_time = -1.0;

void fragment() {
  // 現在のフレーム番号を算出
  float t = anim_time >= 0.0 ? anim_time : TIME;
  int frame = int(mod(t * fps, float(frame_count)));

  // 各フレームのUVオフセットを計算
  vec2 uv = UV;
  uv.x = uv.x / float(frame_count) + float(frame) / float(frame_count);

  COLOR = texture(TEXTURE, uv) * texture(TEXTURE, uv).a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
