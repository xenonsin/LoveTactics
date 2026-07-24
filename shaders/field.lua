-- The one pixel shader every tile FIELD on the battle board is drawn with: a hazard's ground (fire,
-- rain, a Sanctuary), the aura a censer or a banner holds open, the status a unit carries under its
-- feet, and the telegraph an armed ability paints before it lands. See ui/field_fx.lua for the
-- controller that feeds it and docs/architecture.md for why those are all one concept.
--
-- ONE shader with a `uPattern` switch rather than one shader per effect. A field is not really ten
-- different pictures -- it is ten dressings of the same picture: a full tile of animated coverage,
-- tinted, feathered at the footprint's boundary and composited with whatever else stands on the
-- cell. Keeping that shared half in one place is what makes the ten agree with each other, and it
-- means one compile and one bind per family per frame instead of ten live shader objects.
--
-- Plain data at require-time (a string and a table) -- no love.graphics -- so the headless suite can
-- require this and ui/field_fx.lua without a window.
--
-- ---------------------------------------------------------------------------
-- WHAT THE SHADER IS TOLD
--
--   uPattern  int    which family to draw (the PATTERNS table below IS the contract: the Lua names
--                    and the GLSL constants are generated from one list, so they cannot drift apart)
--   uTint     vec4   rgb = the field's colour, a = its final composited alpha (already normalised
--                    across everything else standing on this tile -- see FieldFx.stack)
--   uTime     float  seconds, shared by every field on the board so they animate in one clock
--   uCell     vec2   the tile's BOARD coordinate. Noise is sampled at uCell + texture_coords, i.e.
--                    in board space -- so a 3x3 fire is one continuous churn instead of nine copies
--                    of an identical 1x1 loop. This is the single detail that makes a multi-tile
--                    footprint read as a patch of ground rather than as a grid of squares.
--   uShape    vec2   x = intensity (the def's own density), y = fade (birth ramp * death fade)
--   uEdge     vec4   left, right, top, bottom: 1 where the neighbouring tile does NOT carry this
--                    same field. Only those sides are feathered; interior seams stay hard, so the
--                    field's silhouette is the FOOTPRINT's silhouette and nothing else.
-- ---------------------------------------------------------------------------

local Noise = require("shaders.noise")

local Field = {}

-- The pattern vocabulary, in the order their integer ids run. Ten families cover all 24 hazard
-- blueprints, the field-worthy statuses and the telegraphs -- see ui/field_fx.lua's TAG_PATTERN for
-- what resolves to what, and note that ONE tag table serves all three sources.
Field.ORDER = {
    "flame", -- licking tongues over a hot core, rising
    "smoke", -- churning volumetric haze that desaturates what it covers
    "rime",  -- crystalline facets creeping inward from the footprint's edge
    "rain",  -- falling streaks and expanding ripple rings
    "spark", -- arcing filaments punctuated by a stochastic strobe
    "mire",  -- slow viscous swirl, sinking toward the tile's middle
    "rune",  -- a rotating sigil ring over a faint glyph field
    "halo",  -- soft radial glow with motes drifting up out of it
    "banner",-- a woven chevron weave pulsing outward from the tile
    "ward",  -- a hexagonal shield lattice
}

-- name -> integer, the value sent as uPattern.
Field.PATTERNS = {}
for i, name in ipairs(Field.ORDER) do Field.PATTERNS[name] = i - 1 end

-- The GLSL `#define P_FLAME 0` block, generated from the same list the Lua table is -- so the two
-- sides cannot disagree about which number means flame.
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
uniform vec4  uEdge;
]] .. Noise.source .. [[

// Everything below samples in BOARD space (uCell + tc), which is what keeps a patch continuous
// across its tiles.

// --- footprint geometry ----------------------------------------------------

// How deep into the FIELD this pixel sits, 0 at the footprint's outer boundary and 1 well inside.
// A side the field continues across (uEdge component 0) contributes nothing, which is exactly why
// two adjacent tiles of one hazard show no seam between them.
float depth(vec2 tc) {
    float l = mix(1.0, tc.x,       uEdge.x);
    float r = mix(1.0, 1.0 - tc.x, uEdge.y);
    float t = mix(1.0, tc.y,       uEdge.z);
    float b = mix(1.0, 1.0 - tc.y, uEdge.w);
    return min(min(l, r), min(t, b));
}

// --- the ten families ------------------------------------------------------
// Each returns vec2(coverage, hot): how much of the pixel the field covers, and how much of that is
// the bright core rather than the body. The composite below spends the first on alpha and the
// second on brightening the tint, so every family gets its highlight from one rule.

vec2 pat_flame(vec2 P, vec2 tc, float t) {
    vec2 q = P * 3.2;
    q.y -= t * 1.45;                                  // the whole sheet rises
    float warp = fbm(q * 0.7 + t * 0.30);
    float n = fbm(q + warp * 0.65);
    float cover = smoothstep(0.28, 0.72, n);
    float hot = smoothstep(0.58, 0.86, n);
    return vec2(cover, hot);
}

vec2 pat_smoke(vec2 P, vec2 tc, float t) {
    vec2 q = P * 2.0 + vec2(t * 0.13, -t * 0.08);
    float n = fbm(q + fbm(q * 0.5 - t * 0.05) * 0.8);
    // Tight thresholds: a haze spread evenly over the whole tile is indistinguishable from a flat
    // wash, which is what this replaced. The churn has to have visible holes in it to read as churn.
    float cover = smoothstep(0.14, 0.60, n);
    float curl = smoothstep(0.05, 0.0, abs(fract(n * 3.0) - 0.5)) * 0.35; // contour lines in the roll
    return vec2(clamp(cover + curl, 0.0, 1.0), smoothstep(0.62, 0.90, n) * 0.40);
}

vec2 pat_rime(vec2 P, vec2 tc, float t) {
    vec2 c = cellular2(P * 4.0);
    float seam = smoothstep(0.10, 0.0, c.y - c.x);    // the facet edges: bright, thin, angular
    float shard = 1.0 - smoothstep(0.15, 0.75, c.x);  // the flat pale interior of each crystal
    // Frost takes the footprint's rim first and creeps inward, so a fresh field reads as ground
    // being taken rather than ground already lost.
    float creep = 1.0 - smoothstep(0.0, 0.75, depth(tc));
    float cover = clamp(shard * 0.45 + seam * 0.95 + creep * 0.30, 0.0, 1.0);
    float breathe = 0.88 + 0.12 * sin(t * 0.8 + hash21(floor(P)) * TAU);
    return vec2(cover * breathe, seam);
}

vec2 pat_rain(vec2 P, vec2 tc, float t) {
    // Streaks: noise stretched hard along x and scrolled down fast.
    float s = vnoise(vec2(P.x * 15.0, P.y * 2.2 - t * 6.5));
    float streak = smoothstep(0.48, 0.90, s);
    // Ripples: one expanding ring per lattice cell, each on its own phase.
    vec2 gi = floor(P * 2.0);
    vec2 gf = fract(P * 2.0);
    float ph = fract(t * 0.55 + hash21(gi));
    vec2 c = vec2(hash21(gi + 5.1), hash21(gi + 9.3));
    float rr = length(gf - c);
    float ring = smoothstep(0.06, 0.0, abs(rr - ph * 0.55)) * (1.0 - ph);
    float cover = clamp(streak * 0.80 + ring * 0.85 + 0.20, 0.0, 1.0);
    return vec2(cover, max(streak, ring) * 0.65);
}

vec2 pat_spark(vec2 P, vec2 tc, float t) {
    float n = fbm(P * 3.0 + vec2(t * 0.7, -t * 0.5));
    // A thin isoline through the noise reads as a filament arcing across the ground.
    float fil = smoothstep(0.035, 0.0, abs(n - 0.5));
    float fine = smoothstep(0.020, 0.0, abs(fbm(P * 7.0 - t * 1.3) - 0.5)) * 0.7;
    // Stochastic strobe: held for a whole frame-step of time so it snaps rather than pulses.
    float step7 = floor(t * 7.0);
    float flash = step(0.82, fract(sin(step7 * 91.7) * 4371.3));
    // A charged haze under the filaments, so a lone tile is lit ground rather than bare scribbles.
    float charge = smoothstep(0.35, 0.75, n) * 0.28;
    float cover = clamp((fil + fine) * (0.85 + 0.9 * flash) + charge + 0.08, 0.0, 1.0);
    return vec2(cover, clamp(fil * (0.6 + flash), 0.0, 1.0));
}

vec2 pat_mire(vec2 P, vec2 tc, float t) {
    vec2 q = P * 2.4;
    float a = fbm(q * 0.6 + t * 0.06);
    q += vec2(cos(a * TAU), sin(a * TAU)) * 0.40;     // domain warp: the slow viscous turn
    float n = fbm(q + t * 0.04);
    // Contours through the warped noise: the churn has to be VISIBLE as churn, or sucking ground and
    // ordinary dirt are the same brown smudge -- which is exactly the confusion this replaced.
    float swirl = smoothstep(0.07, 0.0, abs(fract(n * 3.5) - 0.5));
    // Sinks toward the middle of the tile, so the ground reads as something to fall into.
    float sink = 1.0 - smoothstep(0.0, 0.85, length(tc - 0.5) * 2.0) * 0.40;
    float cover = clamp((smoothstep(0.18, 0.62, n) * 0.75 + swirl * 0.55) * sink + 0.28, 0.0, 1.0);
    return vec2(cover, swirl * 0.30);
}

vec2 pat_rune(vec2 P, vec2 tc, float t) {
    // A rune is inscribed ON a tile, so this one is deliberately LOCAL (tc) where the rest are
    // board-space: every cell of a circle wears its own sigil, which is what a graven circle is.
    vec2 d2 = tc - 0.5;
    float d = length(d2) * 2.0;
    float ring = smoothstep(0.075, 0.0, abs(d - 0.80));
    float inner = smoothstep(0.045, 0.0, abs(d - 0.46));
    float ang = atan(d2.y, d2.x);
    float ticks = smoothstep(0.45, 0.98, sin(ang * 8.0 - t * 0.85))
                * smoothstep(0.13, 0.0, abs(d - 0.63));
    float glyph = fbm(P * 6.5) * 0.30 * (1.0 - smoothstep(0.55, 0.98, d));
    float cover = clamp(ring + inner * 0.7 + ticks + glyph, 0.0, 1.0);
    return vec2(cover, clamp(ring + ticks, 0.0, 1.0));
}

vec2 pat_halo(vec2 P, vec2 tc, float t) {
    // POOLS across its footprint rather than glowing per tile. The falloff is driven by depth() --
    // distance from the FIELD's boundary, not from this tile's centre -- so a 3x3 sanctuary is one
    // body of light with a soft rim, where a per-tile radial would have given nine separate blobs
    // and undone the whole point of drawing the footprint as one thing. A lone tile still reads as a
    // single glow, since for one cell "away from the edge" and "toward the middle" are the same
    // direction. (Contrast pat_rune, which is deliberately per-tile: a sigil is inscribed on a cell.)
    float pool = smoothstep(0.0, 0.50, depth(tc)) * (0.62 + 0.16 * sin(t * 1.6));
    float motes = smoothstep(0.80, 0.99, vnoise(vec2(P.x * 7.5, P.y * 7.5 - t * 0.95)));
    float cover = clamp(pool * 0.85 + motes * 0.7 + 0.14, 0.0, 1.0);
    return vec2(cover, clamp(motes + pool * 0.35, 0.0, 1.0));
}

vec2 pat_banner(vec2 P, vec2 tc, float t) {
    // Chevrons in board space, so a banner's square reads as one length of cloth.
    float chev = P.y * 5.0 - abs(fract(P.x) * 2.0 - 1.0) * 2.0;
    float weave = smoothstep(0.15, 0.92, sin(chev * 3.14159 - t * 2.0));
    float pulse = 0.5 + 0.5 * sin(t * 1.5 - length(tc - 0.5) * 6.0);
    float cover = clamp(weave * (0.45 + 0.40 * pulse) + 0.14, 0.0, 1.0);
    return vec2(cover, weave * pulse * 0.7);
}

vec2 pat_ward(vec2 P, vec2 tc, float t) {
    // Hexagonal lattice: pick the nearer of the two offset rectangular lattices, then take the
    // distance to that cell's boundary.
    vec2 uv = P * 2.6;
    vec2 r = vec2(1.0, 1.7320508);
    vec2 h = r * 0.5;
    vec2 a = mod(uv, r) - h;
    vec2 b = mod(uv - h, r) - h;
    vec2 gv = dot(a, a) < dot(b, b) ? a : b;
    vec2 ap = abs(gv);
    float hd = max(ap.x * 0.866 + ap.y * 0.5, ap.y);
    float lattice = smoothstep(0.42, 0.50, hd);
    float sweep = 0.55 + 0.45 * sin(t * 1.2 - (P.x + P.y) * 1.4);
    float cover = clamp(lattice * (0.5 + 0.5 * sweep) + 0.10, 0.0, 1.0);
    return vec2(cover, lattice * sweep);
}

// --- composite -------------------------------------------------------------

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 P = uCell + tc;
    float t = uTime;

    vec2 v = vec2(0.0);
    if      (uPattern == P_FLAME)  v = pat_flame(P, tc, t);
    else if (uPattern == P_SMOKE)  v = pat_smoke(P, tc, t);
    else if (uPattern == P_RIME)   v = pat_rime(P, tc, t);
    else if (uPattern == P_RAIN)   v = pat_rain(P, tc, t);
    else if (uPattern == P_SPARK)  v = pat_spark(P, tc, t);
    else if (uPattern == P_MIRE)   v = pat_mire(P, tc, t);
    else if (uPattern == P_RUNE)   v = pat_rune(P, tc, t);
    else if (uPattern == P_HALO)   v = pat_halo(P, tc, t);
    else if (uPattern == P_BANNER) v = pat_banner(P, tc, t);
    else                           v = pat_ward(P, tc, t);

    // Feather only the sides that are actually the footprint's boundary.
    float rim = smoothstep(0.0, 0.30, depth(tc));

    float cover = clamp(v.x, 0.0, 1.0);
    float hot   = clamp(v.y, 0.0, 1.0);
    float a = cover * uTint.a * uShape.x * uShape.y * rim * color.a;
    if (a <= 0.003) discard;

    vec3 rgb = mix(uTint.rgb, min(uTint.rgb * 2.1 + 0.30, vec3(1.0)), hot);
    return vec4(rgb * color.rgb, a);
}
]]

return Field
