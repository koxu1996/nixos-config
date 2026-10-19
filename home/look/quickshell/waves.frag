#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix; float qt_Opacity;
    float time; float heat; float offset; float energy; float soft; vec2 res;
};
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void main() {
    vec2 sp = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);
    vec2 fc = sp * res;
    float asp = res.x / res.y, px = 1.2 / res.y, t = time;
    float a = clamp(heat * 2.0, 0.0, 1.0), b = clamp(heat * 2.0 - 1.0, 0.0, 1.0);
    vec3 lm = mix(mix(vec3(0.68, 1.00, 0.28), vec3(1.00, 0.90, 0.30), a), vec3(1.00, 0.58, 0.22), b);
    vec3 col = mix(vec3(0.010, 0.016, 0.012), vec3(0.030, 0.050, 0.030), sp.y);
    col += lm * 0.06 * exp(-length((sp - vec2(0.75, 0.95)) * vec2(asp, 1.0)) * 1.8);
    for (int i = 0; i < 5; i++) {
        float fi = float(i), k = fi / 4.0;
        float x = sp.x * asp + offset * (0.15 + 0.12 * fi);
        float ph = t * (0.10 + 0.04 * fi) * (1.0 + heat * 0.8);
        float c = 0.80 - fi * 0.14
                + 0.070 * sin(x * (1.3 + 0.25 * fi) + ph + fi * 1.7)
                + 0.035 * sin(x * (2.9 - 0.2 * fi) - ph * 1.3 + fi * 2.3)
                + 0.012 * sin(x * 6.0 + ph * 2.0 + fi);
        float d = sp.y - c;
        col *= 1.0 - 0.5 * exp(-max(d, 0.0) * 18.0) * step(0.0, d);
        float fill = smoothstep(px * soft, -px * soft, d);
        float lit = smoothstep(-0.32, 0.0, d);
        vec3 deep = mix(vec3(0.015, 0.05, 0.022), lm * 0.16, k);
        vec3 top = lm * (0.22 + 0.62 * k);
        vec3 layer = mix(deep, top, lit * lit);
        layer *= 0.88 + 0.12 * sin(x * 1.7 - t * 0.2 + fi * 2.0);
        col = mix(col, layer, fill);
        float rim = exp(-abs(d) / (px * 3.0 * soft)) / soft; // wider, same total light
        float bloom = exp(-max(d, 0.0) * 45.0) * step(0.0, d);
        col += lm * (rim * 0.5 + bloom * 0.12) * (0.35 + 0.65 * k);
    }
    col += (h2(fc + fract(t * 7.0) * 100.0) - 0.5) * 0.014;
    vec2 v = sp - 0.5;
    col *= 1.0 - dot(v, v) * 0.9;
    col *= mix(0.6, 1.0, energy);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
