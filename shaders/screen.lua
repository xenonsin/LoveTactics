-- The one full-screen post shader the whole game is blitted through (scale.lua composites the logical
-- 1280x720 canvas to the window with it). Unlike the other families this is NOT a pattern switch --
-- every term composes in a single pass, and with all of them at rest the blit skips the shader
-- entirely (scale.lua checks), so a quiet frame costs exactly what it did before any of this existed.
--
-- The terms, in the order they apply:
--   uPunch    a radial zoom-and-chroma kick, for the frame of a killing blow -- the image lurches
--             toward the centre and the colour channels split a hair, then it settles (ui/screen_fx).
--   uBlur     a cheap 5-tap blur, for the frozen scene behind a modal panel.
--   uDesat    drains colour toward luminance: the grey that closes over a defeat.
--   uVignette darkens the edges toward uVignetteColor: the red pulse of a leader near death.
--   uFlash    adds uFlashColor over everything: the white beat of an ultimate loosing.
--
-- Plain string data at require-time, no love.graphics -- ui/screen_fx.lua (which owns the amounts) is
-- required headlessly by the UI-load test, so nothing here may reach for a GPU until scale.lua binds it.

local Screen = {}

Screen.source = [[
extern vec2  uTexel;        // 1/width, 1/height, for the blur taps
extern float uPunch;        // 0 rest .. ~1 a hard kick
extern float uBlur;         // 0 rest .. a few px of radius
extern float uDesat;        // 0 full colour .. 1 greyscale
extern float uVignette;     // 0 none .. 1 heavy
extern vec3  uVignetteColor;
extern float uFlash;        // 0 none .. 1 full
extern vec3  uFlashColor;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = tc;

    // PUNCH: pull the sample point toward the centre (a zoom-in lurch) and split the colour channels
    // radially, so a killing blow snaps the whole frame inward for an instant.
    vec2 fromC = uv - 0.5;
    vec3 rgb;
    if (uPunch > 0.001) {
        uv = 0.5 + fromC * (1.0 - 0.06 * uPunch);
        vec2 split = fromC * 0.010 * uPunch;
        rgb.r = Texel(tex, uv + split).r;
        rgb.g = Texel(tex, uv).g;
        rgb.b = Texel(tex, uv - split).b;
    } else if (uBlur > 0.001) {
        // BLUR: a light 5-tap cross, radius scaled by uBlur. Cheap and stable -- enough to push a
        // scene back behind a panel without a full separable gaussian.
        vec2 o = uTexel * uBlur;
        rgb  = Texel(tex, uv).rgb * 0.4;
        rgb += Texel(tex, uv + vec2( o.x, 0.0)).rgb * 0.15;
        rgb += Texel(tex, uv + vec2(-o.x, 0.0)).rgb * 0.15;
        rgb += Texel(tex, uv + vec2(0.0,  o.y)).rgb * 0.15;
        rgb += Texel(tex, uv + vec2(0.0, -o.y)).rgb * 0.15;
    } else {
        rgb = Texel(tex, uv).rgb;
    }

    // DESAT: toward luminance.
    if (uDesat > 0.001) {
        float l = dot(rgb, vec3(0.299, 0.587, 0.114));
        rgb = mix(rgb, vec3(l), uDesat);
    }

    // VIGNETTE: darken and tint the edges. Distance from centre, eased so the middle stays clean.
    if (uVignette > 0.001) {
        float d = length(fromC) * 1.414;             // 0 centre .. 1 corner
        float v = smoothstep(0.35, 1.0, d) * uVignette;
        rgb = mix(rgb, uVignetteColor, v);
    }

    // FLASH: a flat additive beat over the whole frame.
    rgb += uFlashColor * uFlash;

    return vec4(rgb, 1.0) * color;
}
]]

return Screen
