#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;
    float boost;
};
layout(binding = 1) uniform sampler2D levels;
layout(binding = 2) uniform sampler2D atlas;

void main() {
    vec2 cell = qt_TexCoord0 * grid;
    vec2 ci = floor(cell);
    vec4 l = texture(levels, (ci + 0.5) / grid);
    float lvl = floor(l.r * 255.0 / 16.0 + 0.5) - 1.0;
    if (lvl < 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 f = fract(cell);
    vec4 c = texture(atlas, vec2((lvl + f.x) / 12.0, f.y));
    fragColor = vec4(min(c.rgb * boost, vec3(c.a)), c.a) * qt_Opacity;
}
