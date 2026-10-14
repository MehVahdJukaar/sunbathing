#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D InDepth;
uniform sampler2D LensFlare;

in vec2 texCoord;
out vec4 fragColor;

uniform vec2 InSize;

uniform mat4 PolyProjMat;
uniform mat4 PolyModelViewMat;
uniform float PolySunAngle;

uniform float FlareStrength;

const float PI = 3.14159265;
const float TRANSITION_WIDTH = radians(12.0);

const float FLARE_HALF = 0.35;
const vec3  FLARE_TINT = vec3(1.0, 0.93, 0.80);

float sunWeight(float angle) {
    float t = mod(angle + PI, 2.0 * PI);
    if (t < TRANSITION_WIDTH) return t / TRANSITION_WIDTH;
    else if (t < PI - TRANSITION_WIDTH) return 1.0;
    else if (t < PI + TRANSITION_WIDTH) return 1.0 - (t - (PI - TRANSITION_WIDTH)) / (2.0 * TRANSITION_WIDTH);
    else if (t < 2.0 * PI - TRANSITION_WIDTH) return 0.0;
    else return (t - (2.0 * PI - TRANSITION_WIDTH)) / TRANSITION_WIDTH;
}

vec3 getSunScreenPos() {
    vec3 dir = vec3(cos(PolySunAngle), sin(PolySunAngle), 0.0);
    vec3 camPos = PolyModelViewMat[3].xyz;
    vec3 lightPos = camPos - dir * 1000.0;
    vec4 clip = PolyProjMat * (PolyModelViewMat * vec4(lightPos, 1.0));
    if (clip.w <= 0.0) return vec3(0.0, 0.0, -1.0);
    return vec3((clip.xy / clip.w) * 0.5 + 0.5, clip.w);
}

float skyAt(vec2 uv) {
    float depth = texture(InDepth, clamp(uv, 0.0, 1.0)).r;
    return step(0.999999, depth);
}

void main() {
    vec4 color = texture(DiffuseSampler, texCoord);

    vec3 sun = getSunScreenPos();
    float sunW = sunWeight(PolySunAngle);

    if (sun.z > 0.0 && sunW > 0.0) {
        vec2 sunUV = sun.xy;
        float aspect = InSize.x / InSize.y;

        vec2 tap = 3.0 / InSize;
        float visible = (skyAt(sunUV)
                       + skyAt(sunUV + vec2( tap.x, 0.0))
                       + skyAt(sunUV + vec2(-tap.x, 0.0))
                       + skyAt(sunUV + vec2(0.0,  tap.y))
                       + skyAt(sunUV + vec2(0.0, -tap.y))) * 0.2;

        float edgeFade = smoothstep(0.0, 0.25, sunUV.x) * smoothstep(1.0, 0.75, sunUV.x)
                       * smoothstep(0.0, 0.25, sunUV.y) * smoothstep(1.0, 0.75, sunUV.y);

        float gate = sunW * edgeFade * visible;

        if (gate > 0.0) {
            vec2 fromSun = texCoord - sunUV;
            fromSun.x *= aspect;
            vec2 flareUV = fromSun / (2.0 * FLARE_HALF) + 0.5;

            if (all(greaterThanEqual(flareUV, vec2(0.0))) && all(lessThanEqual(flareUV, vec2(1.0)))) {
                float flare = texture(LensFlare, flareUV).r;
                color.rgb += FLARE_TINT * flare * (FlareStrength * 0.6) * gate;
            }
        }
    }

    fragColor = vec4(color.rgb, 1.0);
}
