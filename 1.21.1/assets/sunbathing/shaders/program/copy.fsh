#version 150

// Full-screen copy back to minecraft:main. Vanilla "blit" uses src-alpha blending which can
// leave the framebuffer unchanged (or corrupt passthrough pixels) when the effect pass wrote
// alpha 0; this pass always replaces with opaque RGB from the swap target.

uniform sampler2D DiffuseSampler;

in vec2 texCoord;
out vec4 fragColor;

void main() {
    fragColor = vec4(texture(DiffuseSampler, texCoord).rgb, 1.0);
}
