-- The pixel shader a unit's own body is drawn through when something is happening TO the body rather
-- than around it: a felled unit burning away (dissolve), a summoned one knitting into being
-- (materialize), a petrified one gone to grey stone. Where shaders/burst.lua draws the event in the air
-- and shaders/field.lua draws the ground, this one works on the sprite texture itself.
--
-- Built to the house contract (docs/architecture.md): ONE shader, a `uMode` switch, the MODES table
-- IS the contract (Lua names and GLSL #defines from one list), plain data at require-time, and its
-- controller (ui/battle_map.lua) compiles it lazily under a pcall so a driver that refuses it falls
-- back to the old flat fade-to-black and the board plays on.
--
-- Unlike the other two families this shader SAMPLES a texture -- the unit's sprite -- so `effect`
-- reads the texel and transforms it, rather than drawing a shape from nothing. A unit with no sprite
-- image (a coloured token) never reaches here; the board keeps its own token path.
--
-- ---------------------------------------------------------------------------
--   uMode   int    which transform (see MODES below)
--   uAmount float  0..1 progress. DISSOLVE: 0 whole, 1 gone. MATERIALIZE: 0 absent, 1 whole.
--                  PETRIFY: how far to stone. So a mode can be tweened by one number.
--   uEdge   vec3   the colour of the burning/knitting boundary (a warm ember for a death, a cold
--                  arcane light for a summon) -- the one detail that tells a dissolve from a fade.
--   uTime   float  seconds, for the petrify sheen. Shared clock is unnecessary here; each is local.
-- ---------------------------------------------------------------------------

local Noise = require("shaders.noise")

local Sprite = {}

Sprite.ORDER = { "dissolve", "materialize", "petrify" }

Sprite.MODES = {}
for i, name in ipairs(Sprite.ORDER) do Sprite.MODES[name] = i - 1 end

local defines = {}
for i, name in ipairs(Sprite.ORDER) do
    defines[#defines + 1] = string.format("#define M_%s %d", name:upper(), i - 1)
end

Sprite.source = table.concat(defines, "\n") .. [[

uniform int   uMode;
uniform float uAmount;
uniform vec3  uEdge;
uniform float uTime;
]] .. Noise.source .. [[

// The dissolve/materialize threshold field over the sprite: soft fbm, so the body comes apart in
// ragged patches rather than on a hard line. Sampled in texture space -- a big sprite and a small one
// burn at the same grain, which is what we want, since a unit is one creature whatever its footprint.
float grain(vec2 tc) {
    return fbm(tc * 6.0 + 3.1);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 texel = Texel(tex, tc);
    if (texel.a <= 0.003) discard;                    // the sprite's own transparent margin stays gone

    if (uMode == M_DISSOLVE || uMode == M_MATERIALIZE) {
        float n = grain(tc);
        // DISSOLVE burns from n=0 upward as uAmount rises; MATERIALIZE reveals the same way in reverse.
        // Fold both into one `a` = how far this pixel is past the moving threshold.
        float thr = (uMode == M_DISSOLVE) ? uAmount : (1.0 - uAmount);
        float past = n - thr;                          // >0 still present, <0 already gone
        if (past < 0.0) discard;
        // A bright edge band just inside the boundary: the ember that eats a corpse, the light that
        // knits a summon. Fades from uEdge at the boundary back to the sprite's own colour within.
        float edge = 1.0 - smoothstep(0.0, 0.16, past);
        vec3 rgb = mix(texel.rgb * color.rgb, uEdge, edge * 0.85);
        // The very lip glows a touch hotter than opaque so it reads as heat/light, not just a colour.
        rgb += uEdge * edge * 0.4;
        return vec4(rgb, texel.a * color.a);
    }

    // PETRIFY: drain the colour to a cold stone, cut facets across it with cell noise, and hold. A
    // static state, not a transition -- uAmount is "how petrified", so a partial application reads.
    float g = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
    vec3 stone = mix(vec3(g), vec3(0.55, 0.58, 0.66) * (0.4 + g * 0.6), 0.7);
    vec2 cel = cellular2(tc * 7.0);
    float facet = smoothstep(0.06, 0.0, cel.y - cel.x); // bright seams between the crystal faces
    stone += facet * 0.25;
    // A slow sheen crawling across the stone so it is not wholly dead on the board.
    stone += 0.06 * sin(tc.x * 10.0 + tc.y * 6.0 - uTime * 1.5);
    vec3 rgb = mix(texel.rgb * color.rgb, stone, clamp(uAmount, 0.0, 1.0));
    return vec4(rgb, texel.a * color.a);
}
]]

return Sprite
