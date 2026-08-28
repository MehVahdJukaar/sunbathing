#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D InDepth;

in vec2 texCoord;
out vec4 fragColor;

uniform vec2 InSize;

uniform mat4 PolyProjMat;

uniform float DofStrength;
uniform float DofRange;

const float MAX_RADIUS = 8.0;
const float FAR_CLAMP = 128.0;

const vec2 DISC[12] = vec2[12](
    vec2( 0.2041,  0.0000),
    vec2(-0.2607,  0.2388),
    vec2( 0.0399, -0.4547),
    vec2( 0.3286,  0.4286),
    vec2(-0.6030, -0.1067),
    vec2( 0.5712, -0.3634),
    vec2(-0.1911,  0.7107),
    vec2(-0.3644, -0.7016),
    vec2( 0.7906,  0.2887),
    vec2(-0.8224,  0.3395),
    vec2( 0.3965, -0.8472),
    vec2( 0.2930,  0.9341)
);

float viewDistance(mat4 invProj, float depth) {
    if (depth >= 1.0) return FAR_CLAMP;
    vec4 view = invProj * vec4(0.0, 0.0, depth * 2.0 - 1.0, 1.0);
    return min(-view.z / view.w, FAR_CLAMP);
}

void main() {
    vec4 color = texture(DiffuseSampler, texCoord);

    mat4 invProj = inverse(PolyProjMat);
    float focusDist = viewDistance(invProj, texture(InDepth, vec2(0.5)).r);
    float dist = viewDistance(invProj, texture(InDepth, texCoord).r);

    float coc = clamp((dist - focusDist) / max(DofRange, 0.5), 0.0, 1.0);
    float radius = coc * DofStrength * MAX_RADIUS;

    if (radius > 0.5) {
        vec2 px = radius / InSize;
        vec3 sum = color.rgb;
        for (int i = 0; i < 12; i++) {
            sum += texture(DiffuseSampler, texCoord + DISC[i] * px).rgb;
        }
        color.rgb = sum / 13.0;
    }

    fragColor = color;
}
