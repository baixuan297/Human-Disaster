shader_type canvas_item;

// --- 颜色 ---
uniform vec4 base_color : source_color = vec4(0.0, 0.7, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.4, 0.95, 1.0, 1.0);
uniform float glow_intensity : hint_range(1.0, 6.0) = 2.5;

// --- 波浪 ---
uniform float wave_speed : hint_range(0.1, 3.0) = 0.6;
uniform float wave_amplitude : hint_range(0.02, 0.35) = 0.15;
uniform float strand_thickness : hint_range(0.004, 0.04) = 0.014;

// --- 流动 ---
uniform float flow_speed : hint_range(0.5, 10.0) = 2.5;
uniform float pulse_speed : hint_range(0.5, 5.0) = 1.2;

// --- 生长动画 ---
uniform float progress : hint_range(0.0, 1.0) = 1.0;

// 单条触须的亮度贡献
float tendril(float along, float across, float freq, float amp, float phase, float thick) {
    // 双谐波叠加：主波 + 副波，形成有机感
    float wave = amp * (
        sin(along * freq + TIME * wave_speed + phase) * 0.65
        + sin(along * freq * 2.1 - TIME * wave_speed * 0.5 + phase * 1.7) * 0.35
    );
    float wave_center = 0.5 + wave;

    float d = abs(across - wave_center);

    // 亮芯
    float core = exp(-d * d / (thick * thick));
    // 中辉光
    float mid = exp(-d * d / (thick * thick * 6.0));
    // 外辉光
    float outer = exp(-d * d / (thick * thick * 25.0));

    // 沿线流动光斑
    float flow = sin(along * 20.0 - TIME * flow_speed + phase * 0.8) * 0.5 + 0.5;
    flow = pow(flow, 2.5);

    return core * (0.7 + 0.3 * flow) + mid * (0.2 + 0.3 * flow) + outer * 0.12;
}

void fragment() {
    float along = UV.x;
    float across = UV.y;

    // ========== 生长裁剪 ==========
    float edge = smoothstep(progress + 0.015, progress - 0.04, along);
    if (edge < 0.001) {
        discard;
    }

    // ========== 七条触须（主干 + 细丝） ==========
    // 3 条主触须：粗、振幅大
    float t1 = tendril(along, across, 3.0, wave_amplitude,        0.0,   strand_thickness);
    float t2 = tendril(along, across, 3.8, wave_amplitude * 0.85, 2.094, strand_thickness * 0.9);
    float t3 = tendril(along, across, 4.7, wave_amplitude * 0.7,  4.189, strand_thickness * 0.85);
    // 4 条细丝：更快更细，填充空隙
    float t4 = tendril(along, across, 5.5, wave_amplitude * 0.55, 1.047, strand_thickness * 0.55);
    float t5 = tendril(along, across, 6.3, wave_amplitude * 0.45, 3.142, strand_thickness * 0.5);
    float t6 = tendril(along, across, 7.2, wave_amplitude * 0.6,  5.236, strand_thickness * 0.45);
    float t7 = tendril(along, across, 8.5, wave_amplitude * 0.35, 0.785, strand_thickness * 0.4);

    float combined = t1 + t2 + t3 + t4 * 0.6 + t5 * 0.5 + t6 * 0.5 + t7 * 0.4;

    // ========== 全局脉冲 ==========
    float pulse = sin(TIME * pulse_speed) * 0.12 + 0.88;
    combined *= pulse;

    // ========== 生长前端光斑 ==========
    float tip_d = abs(along - progress);
    float tip = exp(-tip_d * tip_d * 600.0) * 0.5;
    combined += tip;

    // ========== 颜色：亮芯偏白/accent，外围偏base ==========
    float bright = clamp((combined - 0.4) * 2.5, 0.0, 1.0);
    vec3 color = mix(base_color.rgb, accent_color.rgb, bright) * glow_intensity;

    float final_alpha = clamp(combined, 0.0, 1.0) * edge * base_color.a;

    COLOR = vec4(color, final_alpha);
}
