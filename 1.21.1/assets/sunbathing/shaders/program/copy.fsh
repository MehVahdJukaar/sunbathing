#version 150

// Copy back to minecraft:main with alpha forced to 1: vanilla blit blends by src alpha, so an effect pass that wrote
// alpha 0 would leave the framebuffer untouched.

uniform sampler2D DiffuseSampler;

in vec2 texCoord;
out vec4 fragColor;

void main() {
    fragColor = vec4(texture(DiffuseSampler, texCoord).rgb, 1.0);
}
