#version 330

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
in vec3 skyPos;

out vec4 fragColor;

// from assets/minecraft/polytone/shader_modifiers/core/sky.json
layout(std140) uniform CloudsEnabled { float uCloudsEnabled; };
layout(std140) uniform CloudCoverage { float uCloudCoverage; };
layout(std140) uniform CloudDensity  { float uCloudDensity; };
layout(std140) uniform CloudScale    { float uCloudScale; };
layout(std140) uniform CloudSpeed    { float uCloudSpeed; };
layout(std140) uniform CloudTime     { float uCloudTime; };
layout(std140) uniform CamX          { float uCamX; };
layout(std140) uniform CamZ          { float uCamZ; };

// height of the flat cloud plane above the camera, in blocks
const float CLOUD_HEIGHT = 128.0;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// rotated each octave to avoid axis-aligned artifacts
float fbm(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 5; i++) {
        sum += amp * valueNoise(p);
        p = rot * p;
        amp *= 0.5;
    }
    return sum;
}

void main() {
    // vanilla sky
    vec4 sky = apply_fog(ColorModulator, sphericalVertexDistance, cylindricalVertexDistance,
                         0.0, FogSkyEnd, FogSkyEnd, FogSkyEnd, FogColor);

    vec3 dir = normalize(skyPos);
    float elevation = dir.y;

    // upper hemisphere only, which also skips the lower "sky dark" disc
    float horizon = smoothstep(0.02, 0.30, elevation);
    // hard gate: an unbound UBO reads 0, so clouds stay off on paths where the uniform doesn't reach the shader
    float enabled = step(0.5, uCloudsEnabled);
    float amount = enabled * horizon;

    float cloudMask = 0.0;

    if (amount > 0.0) {
        // where the view ray meets the cloud plane, in world xz, so clouds are pinned to the world
        vec2 proj = skyPos.xz / max(skyPos.y, 0.001);
        vec2 worldXZ = vec2(uCamX, uCamZ) + proj * CLOUD_HEIGHT;

        vec2 wind = vec2(1.0, 0.35) * uCloudTime * uCloudSpeed * 0.004;
        vec2 uv = worldXZ * (0.008 * uCloudScale) + wind;

        float n = fbm(uv);
        float edge = mix(0.75, 0.15, clamp(uCloudCoverage, 0.0, 1.0));
        float soft = mix(0.30, 0.04, clamp(uCloudDensity, 0.0, 1.0));
        float cloud = smoothstep(edge, edge + soft, n);

        // fake thickness: lit top, shaded underside
        float thick = smoothstep(edge - 0.10, 1.0, n);
        vec3 litCol  = vec3(1.00, 0.99, 0.96);
        vec3 baseCol = vec3(0.62, 0.66, 0.74);
        vec3 cloudCol = mix(baseCol, litCol, thick);
        cloudCol = mix(cloudCol, cloudCol * (0.6 + 0.8 * sky.rgb), 0.30);

        sky.rgb = mix(sky.rgb, cloudCol, cloud * amount);
        cloudMask = smoothstep(0.3, 0.7, cloud) * horizon;
    }

    fragColor = sky;

    // reversed-Z far plane is 0.0; clouds sit a hair in front so depth-sampling post effects (godrays) treat them
    // as occluders. Needs sky_depth_write on the sky pipeline.
    gl_FragDepth = cloudMask * 0.00002;
}
