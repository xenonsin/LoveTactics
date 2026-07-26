-- The one pixel shader every tile FIELD on the battle board is drawn with: a hazard's ground (a threat,
-- a Sanctuary, a rally square), the aura a censer or a banner holds open, the status a unit carries
-- under its feet, and the telegraph an armed ability paints before it lands. See ui/field_fx.lua for
-- the controller that feeds it and docs/architecture.md for why those are all one concept.
--
-- ONE shader with a `uPattern` switch rather than one shader per shape. A field is not really several
-- different pictures -- it is a few dressings of the same picture: a full tile of animated coverage,
-- tinted, feathered at the footprint's boundary and composited with whatever else stands on the cell.
-- Keeping that shared half in one place is what makes the shapes agree with each other, and it means
-- one compile and one bind per shape per frame.
--
-- ---------------------------------------------------------------------------
-- TWO SHAPES, NOT TEN ELEMENTS
--
-- The board used to draw a distinct picture per ELEMENT -- flame, rime, rain, spark, mire... -- which
-- read as clutter the moment two zones sat near each other. It now draws by what a zone MEANS to the
-- player, in two shapes the controller colours and points per category (see ui/field_fx.lua's
-- CATEGORY):
--
--   chevron  animated arrows. `uDir` points and scrolls them: -1 down for a hostile zone, +1 up for a
--            friendly one. The colour (orange for a threat, green for your buff, red for the enemy's)
--            is the controller's, not the shape's.
--   cross    a filled tile of small medical crosses -- a heal zone. Blue where it mends your side, red
--            where it mends theirs.
-- ---------------------------------------------------------------------------
-- WHAT THE SHADER IS TOLD
--
--   uPattern  int    which shape to draw (the PATTERNS table below IS the contract: the Lua names and
--                    the GLSL constants are generated from one list, so they cannot drift apart)
--   uTint     vec4   rgb = the field's colour, a = its final composited alpha (already normalised
--                    across everything else standing on this tile -- see FieldFx.stack)
--   uTime     float  seconds, shared by every field on the board so they animate in one clock
--   uCell     vec2   the tile's BOARD coordinate. Noise is sampled at uCell + texture_coords, i.e.
--                    in board space -- so a 3x3 zone is one continuous run of chevrons instead of nine
--                    copies of an identical 1x1 loop. This is the single detail that makes a multi-tile
--                    footprint read as a patch of ground rather than as a grid of squares.
--   uShape    vec2   x = intensity (the def's own density), y = fade (birth ramp * death fade)
--   uDir      float  +1 an upward (friendly) chevron, -1 a downward (hostile) one; unused by the cross
--   uEdge     vec4   left, right, top, bottom: 1 where the neighbouring tile does NOT carry this same
--                    field. Only those sides are feathered; interior seams stay hard, so the field's
--                    silhouette is the FOOTPRINT's silhouette and nothing else.
-- ---------------------------------------------------------------------------

local Noise = require("shaders.noise")

local Field = {}

-- The shape vocabulary, in the order their integer ids run. Two shapes cover every hazard, the
-- field-worthy statuses and the telegraphs -- see ui/field_fx.lua's CATEGORY for what resolves to
-- what, and note that ONE table serves all three sources.
Field.ORDER = {
    "chevron", -- animated arrows, pointed and scrolled by uDir (down = hostile, up = friendly)
    "cross",   -- a filled tile of small medical crosses (a heal zone)
}

-- name -> integer, the value sent as uPattern.
Field.PATTERNS = {}
for i, name in ipairs(Field.ORDER) do Field.PATTERNS[name] = i - 1 end

-- The GLSL `#define P_CHEVRON 0` block, generated from the same list the Lua table is -- so the two
-- sides cannot disagree about which number means which shape.
local defines = {}
for i, name in ipairs(Field.ORDER) do
    defines[#defines + 1] = string.format("#define P_%s %d", name:upper(), i - 1)
end

Field.source = table.concat(defines, "\n") .. [[

uniform int   uPattern;
uniform vec4  uTint;
uniform float uTime;
uniform vec2  uCell;
uniform vec2  uShape;
uniform float uDir;
uniform vec4  uEdge;
]] .. Noise.source .. [[

// Everything below samples in BOARD space (uCell + tc), which is what keeps a patch continuous across
// its tiles.

// --- footprint geometry ----------------------------------------------------

// How deep into the FIELD this pixel sits, 0 at the footprint's outer boundary and 1 well inside. A
// side the field continues across (uEdge component 0) contributes nothing, which is exactly why two
// adjacent tiles of one zone show no seam between them.
float depth(vec2 tc) {
    float l = mix(1.0, tc.x,       uEdge.x);
    float r = mix(1.0, 1.0 - tc.x, uEdge.y);
    float t = mix(1.0, tc.y,       uEdge.z);
    float b = mix(1.0, 1.0 - tc.y, uEdge.w);
    return min(min(l, r), min(t, b));
}

// --- the two shapes --------------------------------------------------------
// Each returns vec2(coverage, hot): how much of the pixel the field covers, and how much of that is
// the bright core rather than the body. The composite below spends the first on alpha and the second
// on brightening the tint, so both shapes get their highlight from one rule.

// Chevrons in board space, pointed and scrolled along uDir. Subtracting the per-column ramp is what
// tilts flat rows into V's, and driving the scroll by uDir is what makes a friendly zone's arrows
// climb while a hostile zone's fall.
vec2 pat_chevron(vec2 P, vec2 tc, float t) {
    float rows = 3.2;                                 // chevrons per board unit, vertically
    float cols = 3.2;
    float col = abs(fract(P.x * cols) - 0.5) * 2.0;   // 0 at a column's centre, 1 at its edge
    float y = P.y * rows - uDir * t * 1.25 - col * 0.85; // apex leads the arms, whole sheet scrolls
    float band = fract(y);
    float bar = smoothstep(0.34, 0.14, abs(band - 0.5)); // one thick arrow per period
    float cover = clamp(bar * 0.92 + 0.12, 0.0, 1.0);    // a faint wash so a lone tile isn't bare arrows
    return vec2(cover, bar);
}

// A filled tile of small crosses: the background is the flat coverage that makes it read as a zone,
// the crosses are the bright core drifting gently up out of it and twinkling out of phase cell to cell.
vec2 pat_cross(vec2 P, vec2 tc, float t) {
    float bg = 0.42;                                  // the filled background ("on a blue background")
    float s = 3.0;                                    // crosses per board unit
    vec2 cellId = floor(P * s + vec2(0.0, t * 0.25));
    vec2 g = fract(P * s + vec2(0.0, t * 0.25)) - 0.5;
    float twinkle = 0.62 + 0.38 * sin(t * 2.2 + hash21(cellId) * TAU);
    float arm = 0.14, len = 0.36;
    float v = step(abs(g.x), arm) * step(abs(g.y), len);
    float h = step(abs(g.y), arm) * step(abs(g.x), len);
    float cross = clamp(v + h, 0.0, 1.0) * twinkle;
    float cover = clamp(bg + cross, 0.0, 1.0);
    return vec2(cover, cross);
}

// --- composite -------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 P = uCell + tc;
    float t = uTime;

    vec2 v = (uPattern == P_CROSS) ? pat_cross(P, tc, t) : pat_chevron(P, tc, t);

    // Feather only the sides that are actually the footprint's boundary.
    float rim = smoothstep(0.0, 0.30, depth(tc));

    float cover = clamp(v.x, 0.0, 1.0);
    float hot   = clamp(v.y, 0.0, 1.0);
    float a = cover * uTint.a * uShape.x * uShape.y * rim * color.a;
    if (a <= 0.003) discard;

    // Brighten the shape's core ALONG ITS OWN HUE, never toward white -- an earlier "+ white" highlight
    // washed the colour out of exactly the brightest pixels, which is fine for orange over brown ground
    // but turned the blue heal-crosses and green buff-chevrons grey. Keep the tint, only lift it.
    vec3 rgb = min(uTint.rgb * (0.85 + 0.55 * hot), vec3(1.0));
    return vec4(rgb * color.rgb, a);
}
]]

return Field
