#version 150

uniform sampler2D DiffuseSampler;

in vec2 texCoord;
out vec4 fragColor;

uniform vec2 InSize;

uniform vec2 BlurDir;

const float WEIGHTS[5] = float[5](0.2270270, 0.1945946, 0.1216216, 0.0540541, 0.0162162);

void main() {
    vec2 stride = BlurDir / InSize * 2.0;

    vec3 sum = texture(DiffuseSampler, texCoord).rgb * WEIGHTS[0];
    for (int i = 1; i < 5; i++) {
        vec2 off = stride * float(i);
        sum += texture(DiffuseSampler, texCoord + off).rgb * WEIGHTS[i];
        sum += texture(DiffuseSampler, texCoord - off).rgb * WEIGHTS[i];
    }
    fragColor = vec4(sum, 1.0);
}
