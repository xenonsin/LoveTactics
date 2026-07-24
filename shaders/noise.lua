-- The GLSL preamble every shader family in shaders/ prepends: hash noise, and the two things built
-- on it. Plain string data, no love.graphics -- required at load by shaders/field.lua and
-- shaders/burst.lua, both of which are themselves required headlessly (see CLAUDE.md).
--
-- Hash-based rather than texture-based on purpose: there is no image to load, nothing to go missing,
-- and models/sprite.lua's tolerance for absent art never has to cover the effects layer.
--
-- One copy, because two copies drift. When fire's ground and fire's blast are drawn by different
-- shaders sampling different noise they stop looking like the same fire, and that is the entire thing
-- the motif vocabulary (ui/motif.lua) exists to prevent -- undone at the last step by a stray 2.03.

local Noise = {}

Noise.source = [[
const float TAU = 6.2831853;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

// Distances to the nearest TWO scattered feature points. The first is the classic cell distance; the
// gap between them is near zero exactly on the boundary between two cells, which is what draws a
// crystal's facet SEAMS rather than a field of blobs -- the difference between frost and bubbles.
vec2 cellular2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float f1 = 8.0;
    float f2 = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = vec2(float(x), float(y));
            vec2 o = vec2(hash21(i + g), hash21(i + g + 31.7));
            float d = length(g + o - f);
            if (d < f1) { f2 = f1; f1 = d; }
            else if (d < f2) { f2 = d; }
        }
    }
    return vec2(f1, f2);
}
]]

return Noise
