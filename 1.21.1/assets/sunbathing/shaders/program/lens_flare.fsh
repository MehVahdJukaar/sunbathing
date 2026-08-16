#version 150

// 1.21.1 port of the base lens_flare.fsh: GLSL 150, plain uniforms, vanilla PostPass names.

uniform sampler2D DiffuseSampler;
uniform sampler2D InDepth;          // bound by Polytone with use_depth_buffer
uniform sampler2D LensFlare;        // grayscale "nova" sprite, CC0 via OpenGameArt; from the samplers map

in vec2 texCoord;
out vec4 fragColor;

uniform vec2 InSize;

uniform mat4 PolyProjMat;
uniform mat4 PolyModelViewMat;
uniform float PolySunAngle;

// config slider via expression_uniforms
uniform float FlareStrength;

const float PI = 3.14159265;
const float TRANSITION_WIDTH = radians(12.0);

const float FLARE_HALF = 0.35;                  // sprite half-size, fraction of screen height
const vec3  FLARE_TINT = vec3(1.0, 0.93, 0.80);

// same sun/moon crossfade as godrays.fsh
float sunWeight(float angle) {
    float t = mod(angle + PI, 2.0 * PI);
    if (t < TRANSITION_WIDTH) return t / TRANSITION_WIDTH;
    else if (t < PI - TRANSITION_WIDTH) return 1.0;
    else if (t < PI + TRANSITION_WIDTH) return 1.0 - (t - (PI - TRANSITION_WIDTH)) / (2.0 * TRANSITION_WIDTH);
    else if (t < 2.0 * PI - TRANSITION_WIDTH) return 0.0;
    else return (t - (2.0 * PI - TRANSITION_WIDTH)) / TRANSITION_WIDTH;
}

// screen uv in .xy, clip w in .z (> 0 means in front of the camera)
vec3 getSunScreenPos() {
    vec3 dir = vec3(cos(PolySunAngle), sin(PolySunAngle), 0.0);
    vec3 camPos = PolyModelViewMat[3].xyz;
    vec3 lightPos = camPos - dir * 1000.0;
    vec4 clip = PolyProjMat * (PolyModelViewMat * vec4(lightPos, 1.0));
    if (clip.w <= 0.0) return vec3(0.0, 0.0, -1.0);
    return vec3((clip.xy / clip.w) * 0.5 + 0.5, clip.w);
}

// 1.0 on open sky (classic depth: sky = 1.0)
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

        // 5 taps so the flare fades smoothly as terrain crosses the sun
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
