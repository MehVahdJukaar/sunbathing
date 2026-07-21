#version 330

// Directional shadow resolve pass - REVERSED-Z variant (formats 88+, e.g. 1.21.11).
//
// Same math as the base (classic-depth) shadows.fsh, but the level depth buffer is reversed-Z with
// zero-to-one clip: the far plane / sky clears to 0.0 (was 1.0) and NDC z is in [0,1] (not [-1,1]).
// Only the sky test and the NDC z used for position reconstruction change; everything downstream
// (light projection, PCF, bias, edge fade) is identical because the shadow map has its own ortho
// projection that is unaffected by the main scene's depth convention.

uniform sampler2D InSampler;        // scene colour (pass input "In")
uniform sampler2D InDepthSampler;   // level depth (pass input "InDepth" with use_depth_buffer)
uniform sampler2D InShadow;         // light-POV depth map (Polytone binds it by name)

in vec2 texCoord;
out vec4 fragColor;

layout(std140) uniform PolyGlobals {
    mat4 PolyProjMat;               // camera projection (reversed-Z)
    mat4 PolyModelViewMat;          // camera view (rotation only; camera at origin)
    float PolySunAngle;
};

layout(std140) uniform PolyShadow {
    mat4 PolyShadowMat;             // light view-projection, camera-relative space
    vec3 PolyShadowLightDir;        // unit direction toward the light, camera-relative space
    vec3 PolyShadowCamFract;        // fract(cameraPos): world-grid anchor for camera-relative coords
};

// From expression_uniforms in polytone/post_shaders/shadows.json
layout(std140) uniform ShadowStrength { float uShadowStrength; };  // 0..1, how dark full shadow gets
layout(std140) uniform ShadowBias     { float uShadowBias; };      // base depth bias (normalized light depth)
layout(std140) uniform NormalOffset   { float uNormalOffset; };    // sample offset along the surface normal, in blocks
layout(std140) uniform PixelGridRes   { float uPixelGridRes; };    // world-grid cells per block; 0 = smooth

void main() {
    vec3 color = texture(InSampler, texCoord).rgb;
    float depth = texture(InDepthSampler, texCoord).r;

    // Reversed-Z: the far plane / sky clears to 0.0, so a ~0 depth means "nothing to shadow".
    if (depth <= 0.000001) {
        fragColor = vec4(color, 1.0);
        return;
    }

    // Screen -> camera-relative world position. Under zero-to-one clip the depth texture already
    // holds NDC z directly (near = 1, far = 0), so it is used as-is - no * 2.0 - 1.0 remap. Only x/y
    // are still in [-1,1].
    vec4 ndc = vec4(texCoord * 2.0 - 1.0, depth, 1.0);
    vec4 viewPos = inverse(PolyProjMat) * ndc;
    viewPos /= viewPos.w;
    vec3 worldRel = (inverse(PolyModelViewMat) * viewPos).xyz;

    // Reconstruct the surface normal from screen-space derivatives of the world position, oriented to
    // face the camera (which is at the origin in this space).
    vec3 normal = normalize(cross(dFdx(worldRel), dFdy(worldRel)));
    if (dot(normal, worldRel) > 0.0) normal = -normal;

    // How edge-on the surface is to the light: 0 when facing it, ->1 when grazing/away.
    float slope = clamp(1.0 - dot(normal, PolyShadowLightDir), 0.0, 1.0);

    // Push the sample point off the surface along its normal BEFORE any grid snapping: it removes
    // acne on walls, and it guarantees snapped cell centers sit outside the surface's own block
    // (surfaces lie exactly on grid lines, so an un-offset snap would coin-flip into self-shadow).
    vec3 samplePos = worldRel + normal * (uNormalOffset * (1.0 + 2.0 * slope));

    // Snap to the center of a world-aligned grid cell (grid anchored at absolute block corners).
    if (uPixelGridRes > 0.5) {
        float g = 1.0 / uPixelGridRes;
        samplePos = (floor((samplePos + PolyShadowCamFract) / g) + 0.5) * g - PolyShadowCamFract;
    }

    // Camera-relative world -> light clip space -> [0,1] shadow-map coords.
    vec4 lightClip = PolyShadowMat * vec4(samplePos, 1.0);
    vec3 proj = lightClip.xyz / lightClip.w;
    vec3 suv = proj * 0.5 + 0.5;

    // Outside the (single cascade) shadow frustum -> treat as lit.
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0 || suv.z > 1.0) {
        fragColor = vec4(color, 1.0);
        return;
    }

    // Slope-scaled depth bias: surfaces edge-on to the light need more.
    float bias = uShadowBias * (1.0 + 6.0 * slope);

    // 3x3 PCF. With the pixel grid on, the result is constant per world cell, so this reads as a
    // per-cell penumbra level (soft but still blocky) rather than a smooth screen-space blur.
    float shadow = 0.0;
    vec2 texel = 1.0 / vec2(textureSize(InShadow, 0));
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            float occluder = texture(InShadow, suv.xy + vec2(dx, dy) * texel).r;
            shadow += (suv.z - bias > occluder) ? 1.0 : 0.0;
        }
    }
    shadow /= 9.0;

    // Fade shadows toward the edge of the single cascade instead of hard-cutting at the coverage
    // boundary, so they don't pop in/out as the camera moves and the covered box slides over the
    // world. d = 0 at the map center, 1 at the border; fade the outer ~15% ring.
    vec2 d = abs(suv.xy - 0.5) * 2.0;
    float edgeFade = 1.0 - smoothstep(0.85, 1.0, max(max(d.x, d.y), suv.z));
    shadow *= edgeFade;

    color *= (1.0 - shadow * uShadowStrength);
    fragColor = vec4(color, 1.0);
}
