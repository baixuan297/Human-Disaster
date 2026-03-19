shader_type canvas_item;

// 六边形裁剪：与 skill_button_hex 的 hex_size 一致
uniform float hex_size : hint_range(0.25, 0.5) = 0.42;

float hex_dist(vec2 p) {
    p = abs(p);
    return max(p.x, p.x * 0.5 + p.y * 0.866025);
}

void fragment() {
    vec2 uv = UV - 0.5;
    float d = hex_dist(uv);

    if (d > hex_size) {
        discard;
    }

    vec4 tex = texture(TEXTURE, UV);
    COLOR = tex;
}
