#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;
    vec2 ab;
};

const float R1 = 1.0;
const float R2 = 2.0;
const float K2 = 5.0;

void main() {
    float k1 = grid.x * K2 * 3.0 / (8.0 * (R1 + R2));
    vec2 cell = floor(qt_TexCoord0 * grid) + 0.5;
    vec3 dir = vec3((cell.x - grid.x * 0.5) / k1, -(cell.y - grid.y * 0.5) / (k1 * 0.5), 1.0);
    float len = length(dir);
    float cA = cos(ab.x), sA = sin(ab.x), cB = cos(ab.y), sB = sin(ab.y);
    float s = K2 - R1 - R2 - 0.5;
    vec3 q = vec3(0.0);
    bool hit = false;
    for (int i = 0; i < 64; i++) {
        vec3 w = dir * s - vec3(0.0, 0.0, K2);
        vec3 v = vec3(w.x * cB + w.y * sB, -w.x * sB + w.y * cB, w.z);
        q = vec3(v.x, v.y * cA + v.z * sA, -v.y * sA + v.z * cA);
        float d = length(vec2(length(q.xz) - R2, q.y)) - R1;
        if (d < 0.001) {
            hit = true;
            break;
        }
        s += d / len;
        if (s > K2 + R1 + R2 + 0.5)
            break;
    }
    float level = 0.0;
    if (hit) {
        vec3 n = normalize(q - R2 * normalize(vec3(q.x, 0.0, q.z)));
        vec3 r = vec3(n.x, n.y * cA - n.z * sA, n.y * sA + n.z * cA);
        float ny = r.x * sB + r.y * cB;
        float L = ny - r.z;
        if (L > 0.0)
            level = (min(11.0, floor(L * 8.0)) + 1.0) * 16.0 / 255.0;
    }
    fragColor = vec4(level, 0.0, 0.0, 1.0) * qt_Opacity;
}
