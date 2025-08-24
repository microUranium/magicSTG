shader_type canvas_item;
render_mode blend_add;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = tex_color * COLOR;
    COLOR.rgb *= COLOR.a;
}