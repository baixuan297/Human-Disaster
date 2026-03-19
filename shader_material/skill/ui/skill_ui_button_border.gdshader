shader_type canvas_item;

// --- 颜色与强度 ---
uniform vec4 base_color : source_color = vec4(0.0, 0.7, 1.0, 1.0); // 核心蓝光
uniform float glow_intensity : hint_range(1.0, 5.0) = 2.5; // 发光强度 (配合 WorldEnvironment)

// --- 尺寸控制 ---
// 0.0 是中心，0.5 是边缘。你的按钮图片大概在 0.2-0.3 左右，这里留空
uniform float inner_clear_radius : hint_range(0.0, 0.5) = 0.28;
uniform float ring_radius : hint_range(0.0, 0.5) = 0.38;
uniform float ring_width : hint_range(0.0, 0.2) = 0.08;

// --- 动画控制 ---
uniform float speed_1 : hint_range(0.1, 5.0) = 1.0;
uniform float speed_2 : hint_range(0.1, 5.0) = -0.8; // 反向旋转

// --- 辅助函数 ---
float circle_soft(vec2 uv, float radius, float width, float feather) {
    float d = length(uv);
    // 使用 smoothstep 制作非常柔和的边缘
    return smoothstep(width + feather, width, abs(d - radius));
}

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // 如果距离小于清除半径，直接透明，不绘制任何东西（保证不遮挡按钮）
    // 使用 smoothstep 让内边缘不要太生硬
    float center_mask = smoothstep(inner_clear_radius, inner_clear_radius + 0.05, dist);

    // ---------------------------
    // 层级 1: 主能量光环 (波浪状)
    // ---------------------------
    // 动态波浪偏移
    float wave = sin(angle * 3.0 + TIME * speed_1) * 0.02;
    float ring1 = circle_soft(uv, ring_radius + wave, ring_width * 0.5, 0.1);

    // 给光环增加“断层”感，看起来像数据流
    float mask1 = sin(angle * 5.0 - TIME * speed_1 * 2.0);
    mask1 = smoothstep(-0.2, 0.8, mask1); // 柔化断层
    ring1 *= (0.5 + 0.5 * mask1); // 基础亮度 + 动态亮度

    // ---------------------------
    // 层级 2: 外围细丝带 (反向旋转，更细，更虚)
    // ---------------------------
    float wave2 = cos(angle * 4.0 + TIME * speed_2) * 0.015;
    float ring2 = circle_soft(uv, ring_radius + 0.06 + wave2, 0.005, 0.05); // 更细，更外围

    // 细丝带的亮度变化
    float mask2 = sin(angle * 8.0 + TIME * speed_2);
    ring2 *= smoothstep(0.0, 1.0, mask2);

    // ---------------------------
    // 合成
    // ---------------------------
    // 叠加两个环
    float combined_shape = ring1 + ring2;

    // 应用中心遮罩 (挖空中间)
    combined_shape *= center_mask;

    // 最终颜色计算
    vec3 final_color = base_color.rgb * glow_intensity;
    // Alpha 通道由形状决定
    float final_alpha = combined_shape * base_color.a;

    COLOR = vec4(final_color, final_alpha);
}