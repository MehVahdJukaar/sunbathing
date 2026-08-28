#version 330

uniform sampler2D InSampler;

in vec2 texCoord;
out vec4 fragColor;

layout(std140) uniform BloomThreshold { float uBloomThreshold; };

const float KNEE = 0.25;

void main() {
    vec3 color = texture(InSampler, texCoord).rgb;
    float lum = max(color.r, max(color.g, color.b));
    float w = smoothstep(uBloomThreshold, uBloomThreshold + KNEE, lum);
    fragColor = vec4(color * w, 1.0);
}
