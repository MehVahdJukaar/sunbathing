#version 330

uniform sampler2D InSampler;
uniform sampler2D BloomSampler;

in vec2 texCoord;
out vec4 fragColor;

layout(std140) uniform BloomStrength { float uBloomStrength; };

void main() {
    vec4 color = texture(InSampler, texCoord);
    vec3 bloom = texture(BloomSampler, texCoord).rgb;
    fragColor = vec4(color.rgb + bloom * uBloomStrength, color.a);
}
