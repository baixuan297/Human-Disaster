shader_type canvas_item;

// --- 颜色 ---
uniform vec4 fill_color : source_color = vec4(0.02, 0.06, 0.12, 0.85);
uniform vec4 border_color : source_color = vec4(0.0, 0.7, 1.0, 1.0);
uniform float glow_intensity : hint_range(1.0, 5.0) = 2.5;

// --- 形状 ---
uniform float hex_size : hint_range(0.25, 0.48) = 0.42;
uniform float border_width : hint_range(0.005, 0.03) = 0.018;
uniform float glow_spread : hint_range(0.02, 0.12) = 0.05;

// --- 动画 ---
uniform float breath_speed : hint_range(0.0, 3.0) = 0.8;

// 尖顶六边形距离（与 skillTreeButton 一致）
float hex_dist(vec2 p) {
    p = abs(p);
    return max(p.x, p.x * 0.5 + p.y * 0.866025);
}

void fragment() {
    vec2 uv = UV - 0.5;
    float d = hex_dist(uv);

    float breath = sin(TIME * breath_speed) * 0.08 + 0.92;

    // 有符号距离：负=内部，正=外部
    float sd = d - hex_size;

    // ========== 暗色填充 ==========
    float fill = smoothstep(0.008, -0.008, sd);

    // ========== 边框亮线 ==========
    float border = exp(-sd * sd / (border_width * border_width));

    // ========== 内辉光（边框内侧柔和发光）==========
    float inner = exp(-pow(max(-sd, 0.0) / (glow_spread * 0.8), 2.0)) * fill;

    // ========== 外辉光（边框外侧衰减）==========
    float outer = exp(-pow(max(sd, 0.0) / glow_spread, 2.0));

    // ========== 棱角高光（六边形顶点额外亮度）==========
    float angle = atan(uv.y, uv.x);
    float vertex_highlight = pow(abs(sin(angle * 3.0)), 8.0) * border * 0.4;

    // ========== 合成 ==========
    vec3 col = fill_color.rgb * fill;
    col += border_color.rgb * glow_intensity * border * breath;
    col += border_color.rgb * inner * 0.35 * breath;
    col += border_color.rgb * outer * 0.25 * breath;
    col += border_color.rgb * vertex_highlight * glow_intensity * breath;

    float alpha = fill * fill_color.a;
    alpha = max(alpha, border * 0.9);
    alpha = max(alpha, outer * 0.2);
    alpha = clamp(alpha, 0.0, 1.0);

    COLOR = vec4(col, alpha);
}
