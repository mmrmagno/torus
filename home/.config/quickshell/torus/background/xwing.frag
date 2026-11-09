#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;
    vec2 ab;
};

const float K2 = 5.0;

float box(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float capsuleZ(vec3 p, float z0, float z1, float r) {
    p.z -= clamp(p.z, z0, z1);
    return length(p) - r;
}

vec3 spin(vec3 p) {
    float y = ab.x;
    float x = 0.35 * sin(ab.y);
    p = vec3(p.x * cos(y) + p.z * sin(y), p.y, -p.x * sin(y) + p.z * cos(y));
    return vec3(p.x, p.y * cos(x) - p.z * sin(x), p.y * sin(x) + p.z * cos(x));
}

float ship(vec3 p) {
    float body = box(p - vec3(0.0, 0.0, 0.2), vec3(0.16, 0.17, 1.35)) - 0.04;
    float nose = capsuleZ(p * vec3(1.0, 1.15, 1.0), 1.2, 2.1, 0.12);
    float cockpit = length((p - vec3(0.0, 0.2, 0.35)) * vec3(2.6, 3.0, 1.0)) - 0.42;
    vec3 m = vec3(abs(p.x), abs(p.y), p.z);
    float wing = 1e3;
    float a = 0.4;
    vec3 w = vec3(m.x * cos(a) + m.y * sin(a), -m.x * sin(a) + m.y * cos(a), m.z);
    wing = box(w - vec3(1.1, 0.0, -0.75), vec3(0.95, 0.03, 0.42 - 0.12 * (w.x - 0.2)));
    float engine = capsuleZ(m - vec3(0.36, 0.17, 0.0), -1.35, -0.25, 0.13);
    vec3 tip = vec3(2.05 * cos(a), 2.05 * sin(a), 0.0);
    float gun = capsuleZ(m - tip, -1.0, 1.25, 0.05);
    return min(min(min(body, nose), min(cockpit, wing)), min(engine, gun));
}

float scene(vec3 p) {
    return ship(spin(p - vec3(0.0, 0.0, K2)));
}

void main() {
    float k1 = grid.x * K2 * 3.0 / (8.0 * 2.25);
    vec2 cell = floor(qt_TexCoord0 * grid) + 0.5;
    vec3 dir = normalize(vec3((cell.x - grid.x * 0.5) / k1, -(cell.y - grid.y * 0.5) / (k1 * 0.5), 1.0));
    float s = K2 - 3.0;
    bool hit = false;
    for (int i = 0; i < 72; i++) {
        float d = scene(dir * s);
        if (d < 0.002) {
            hit = true;
            break;
        }
        s += d;
        if (s > K2 + 3.0)
            break;
    }
    float level = 0.0;
    if (hit) {
        vec3 p = dir * s;
        vec2 e = vec2(0.002, 0.0);
        vec3 n = normalize(vec3(scene(p + e.xyy) - scene(p - e.xyy), scene(p + e.yxy) - scene(p - e.yxy), scene(p + e.yyx) - scene(p - e.yyx)));
        float L = 0.18 + 0.82 * max(dot(n, normalize(vec3(0.35, 0.8, -0.6))), 0.0);
        level = (min(11.0, floor(L * 11.99)) + 1.0) * 16.0 / 255.0;
    }
    fragColor = vec4(level, 0.0, 0.0, 1.0) * qt_Opacity;
}
