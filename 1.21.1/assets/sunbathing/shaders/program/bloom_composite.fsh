#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D BloomSampler;

in vec2 texCoord;
out vec4 fragColor;

uniform float BloomStrength;

void main() {
    vec4 color = texture(DiffuseSampler, texCoord);
    vec3 bloom = texture(BloomSampler, texCoord).rgb;
    fragColor = vec4(color.rgb + bloom * BloomStrength, color.a);
}
