#version 150

// 1.21.1 (OLD post pipeline) port of the textured lens flare.
// Same logic as the base lens_flare.fsh, but GLSL 150 + individual uniforms + vanilla PostPass
// samplers (DiffuseSampler / InSize), and the depth + flare samplers use the plain names Polytone
// binds (`InDepth` via use_depth_buffer, `LensFlare` via the samplers map). Old depth (sky = 1.0).

uniform sampler2D DiffuseSampler;   // scene colour (vanilla auto-binds the pass intarget)
uniform sampler2D InDepth;          // level depth (Polytone binds it when use_depth_buffer is set)
uniform sampler2D LensFlare;        // "nova" flare sprite (grayscale on black), CC0 via OpenGameArt

in vec2 texCoord;
out vec4 fragColor;

uniform vec2 InSize;                // input target size, provided by vanilla PostPass

// Polytone built-ins (individual uniforms on 1.21.1)
uniform mat4 PolyProjMat;
uniform mat4 PolyModelViewMat;
uniform float PolySunAngle;

// Overall intensity, driven by the "Lens Flare" config slider (0..1) via expression_uniforms.
uniform float FlareStrength;

const float PI = 3.14159265;
const float TRANSITION_WIDTH = radians(12.0);

// --- Single textured lens flare, centred on the sun ---
const float FLARE_HALF = 0.35;                  // sprite half-size, as a fraction of screen height
const vec3  FLARE_TINT = vec3(1.0, 0.93, 0.80); // warm, sun-lit white

// Day weight: 1 when the sun is the active light, 0 at night (mirrors godrays getLightWeights)
float sunWeight(float angle) {
    float t = mod(angle + PI, 2.0 * PI);
    if (t < TRANSITION_WIDTH) return t / TRANSITION_WIDTH;
    else if (t < PI - TRANSITION_WIDTH) return 1.0;
    else if (t < PI + TRANSITION_WIDTH) return 1.0 - (t - (PI - TRANSITION_WIDTH)) / (2.0 * TRANSITION_WIDTH);
    else if (t < 2.0 * PI - TRANSITION_WIDTH) return 0.0;
    else return (t - (2.0 * PI - TRANSITION_WIDTH)) / TRANSITION_WIDTH;
}

// Sun screen-space position; .z (clip.w) > 0 means it's in front of the camera
vec3 getSunScreenPos() {
    vec3 dir = vec3(cos(PolySunAngle), sin(PolySunAngle), 0.0);
    vec3 camPos = PolyModelViewMat[3].xyz;
    vec3 lightPos = camPos - dir * 1000.0;
    vec4 clip = PolyProjMat * (PolyModelViewMat * vec4(lightPos, 1.0));
    if (clip.w <= 0.0) return vec3(0.0, 0.0, -1.0);
    return vec3((clip.xy / clip.w) * 0.5 + 0.5, clip.w);
}

// 1.0 where the sampled pixel is open sky (OLD depth convention: far plane / sky = 1.0).
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

        // soft 5-tap occlusion so the flare fades smoothly as terrain crosses the sun
        vec2 o = 3.0 / InSize;
        float visible = (skyAt(sunUV)
                       + skyAt(sunUV + vec2( o.x, 0.0))
                       + skyAt(sunUV + vec2(-o.x, 0.0))
                       + skyAt(sunUV + vec2(0.0,  o.y))
                       + skyAt(sunUV + vec2(0.0, -o.y))) * 0.2;

        // fade as the sun nears / leaves the screen edges
        float edgeFade = smoothstep(0.0, 0.25, sunUV.x) * smoothstep(1.0, 0.75, sunUV.x)
                       * smoothstep(0.0, 0.25, sunUV.y) * smoothstep(1.0, 0.75, sunUV.y);

        float gate = sunW * edgeFade * visible;

        if (gate > 0.0) {
            // map the pixel into the flare sprite's [0,1] space, kept square via the aspect ratio
            vec2 d = texCoord - sunUV;
            d.x *= aspect;
            vec2 flareUV = d / (2.0 * FLARE_HALF) + 0.5;

            if (all(greaterThanEqual(flareUV, vec2(0.0))) && all(lessThanEqual(flareUV, vec2(1.0)))) {
                // grayscale sprite -> additive warm glow, gated by day/occlusion/edge and the slider
                float flare = texture(LensFlare, flareUV).r;
                color.rgb += FLARE_TINT * flare * (FlareStrength * 0.6) * gate;
            }
        }
    }

    fragColor = color;
}
