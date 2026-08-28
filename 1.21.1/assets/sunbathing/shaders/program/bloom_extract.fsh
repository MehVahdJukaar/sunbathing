#version 150

uniform sampler2D DiffuseSampler;

in vec2 texCoord;
out vec4 fragColor;

uniform float BloomThreshold;

const float KNEE = 0.25;

void main() {
    vec3 color = texture(DiffuseSampler, texCoord).rgb;
    float lum = max(color.r, max(color.g, color.b));
    float w = smoothstep(BloomThreshold, BloomThreshold + KNEE, lum);
    fragColor = vec4(color * w, 1.0);
}
