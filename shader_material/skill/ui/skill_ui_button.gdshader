shader_type canvas_item;

// --- 参数设置 ---
// 主色调，建议选一种青蓝色或亮蓝色
uniform vec4 base_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
// 呼吸速度
uniform float breath_speed : hint_range(0.1, 5.0) = 2.0;
// 旋转圆环的速度
uniform float rotation_speed : hint_range(0.1, 5.0) = 1.0;
// 特效的大小范围 (0.0 - 0.5)
uniform float radius_scale : hint_range(0.1, 1.0) = 0.45;
// 辉光强度
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;

// --- 辅助函数：绘制六边形 ---
// 计算点到六边形中心的距离（用于绘制六边形轮廓）
float hexagon_dist(vec2 p) {
    p = abs(p);
    return max(p.x, p.x * 0.5 + p.y * 0.866025);
}

// --- 辅助函数：绘制圆环 ---
float circle_ring(vec2 uv, float radius, float width, float feather) {
    float d = length(uv);
    return smoothstep(width + feather, width, abs(d - radius));
}

// --- 随机杂色（可选，增加科技感）---
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // 将 UV 坐标中心化，从 (0,0) 到 (1,1) 变为 (-0.5, -0.5) 到 (0.5, 0.5)
    vec2 uv = UV - 0.5;
    
    // 获取极坐标角度 (用于旋转效果)
    float angle = atan(uv.y, uv.x);
    float dist = length(uv);
    
    // ---------------------------
    // 1. 核心呼吸六边形 (匹配你的图标形状)
    // ---------------------------
    float hex_d = hexagon_dist(uv);
    // 呼吸因子
    float breath = sin(TIME * breath_speed) * 0.02;
    // 绘制六边形边缘发光
    float hex_glow = smoothstep(radius_scale + breath + 0.02, radius_scale + breath, hex_d);
    // 挖空中间，只留边缘光晕，如果是实心背景可以去掉这一行
    hex_glow *= smoothstep(radius_scale - 0.1, radius_scale, hex_d); 
    
    
    // ---------------------------
    // 2. 外部旋转科技环 (Outer Ring)
    // ---------------------------
    // 基础圆环
    float ring_radius = radius_scale + 0.08;
    float ring = circle_ring(uv, ring_radius, 0.005, 0.01);
    
    // 制作缺口 (Tech Gaps)
    // 利用 sin 函数根据角度和时间来裁切圆环
    float ring_mask = sin(angle * 3.0 + TIME * rotation_speed); // 3个缺口
    float ring_mask_2 = sin(angle * 10.0 - TIME * rotation_speed * 2.0); // 细节噪点
    
    // 组合圆环效果：只有当 mask > 0.5 时才显示，形成断断续续的科技感
    float tech_ring = ring * step(0.5, ring_mask);
    
    // ---------------------------
    // 3. 装饰性扫描线/粒子
    // ---------------------------
    float particle_ring = circle_ring(uv, ring_radius * 1.2, 0.002, 0.02);
    // 让它反向快速旋转
    float particle_mask = step(0.9, sin(angle * 20.0 - TIME * 3.0));
    float particles = particle_ring * particle_mask;

    // ---------------------------
    // 4. 合成最终颜色
    // ---------------------------
    // 组合所有形状
    float final_alpha = hex_glow + tech_ring + particles;
    
    // 应用颜色和强度
    vec3 final_color = base_color.rgb * glow_intensity;
    
    // 输出
    COLOR = vec4(final_color, final_alpha * base_color.a);
}