-- The one pixel shader every POINT effect on the battle board is drawn with: the mark a blow leaves
-- where it lands (a slash arc, a pierce spike, a crush ring), the bloom of an element (fire, frost,
-- a bolt), the rise of a heal, and the streak of a projectile crossing the board on its way to all of
-- that. See ui/burst_fx.lua for the controller that spawns and feeds it.
--
-- Sibling to shaders/field.lua and built to the same contract (docs/architecture.md): ONE shader with
-- a `uPattern` switch, the PATTERNS table below IS the contract (Lua names and GLSL #defines generated
-- from one list), plain data at require-time so the headless suite can load it, and lazily compiled
-- under a pcall by the controller so a driver that rejects it costs nothing.
--
-- WHERE FIELD ENDS AND BURST BEGINS. A field is a full tile of standing ground, animated on a shared
-- board clock, feathered at a footprint's edge. A burst is a single quad centred on a world POINT with
-- a life of its own: it is born, it plays out over uAge 0..1, and it is gone. A field says "this
-- ground is on fire"; a burst says "fire happened HERE, just now". They share the noise (shaders/noise
-- .lua) and the motif vocabulary (ui/motif.lua) so the two agree about what fire looks like, and
-- nothing else.
--
-- ---------------------------------------------------------------------------
-- WHAT THE SHADER IS TOLD
--
--   uPattern int   which family to draw (see PATTERNS below)
--   uTint    vec4  rgb = the effect's colour, a = its master alpha (the controller's fade envelope)
--   uAge     float 0 at birth, 1 at death -- the burst's own life, NOT a shared clock. Every shape
--                  reads this to grow, throw and fade in one motion.
--   uSeed    float a per-instance hash so two bursts of one family never draw as one doubled copy;
--                  rotates arcs, scatters shards, forks bolts differently each time.
--   uShape   vec2  x = intensity (brightness/density), y = a direction angle in radians (a slash
--                  sweeps across it, a streak travels along it, a pierce drives down it)
--   uAim     vec2  the flight direction for a `streak`, unit length (0,0 for a still burst)
-- ---------------------------------------------------------------------------

local Noise = require("shaders.noise")

local Burst = {}

-- The pattern vocabulary, in the order their integer ids run. Ten shapes cover every motif that
-- leaves a mark plus the projectile that carries it. ui/burst_fx.lua's MOTIF_PATTERN maps the shared
-- vocabulary onto these.
Burst.ORDER = {
    "slash",   -- a bright arc swept across the point, thrown outward as it fades
    "pierce",  -- a narrow lens/spike driven along the hit direction, with a puncture flash
    "crush",   -- an expanding shock ring and a low dust puff: blunt force
    "bloom",   -- a fireball: a hot core throwing licking tongues, rising as it dies
    "shatter", -- frost shards flung radially from a bright freezing flash
    "bolt",    -- a jagged lightning fork with a white overload flash
    "spray",   -- a soft expanding puff of droplets: poison, acid, rot
    "flare",   -- radiant rays fanning from a bright centre: holy, light
    "sigil",   -- a rune ring snapping open then dissolving: arcane
    "motes",   -- soft points rising and fading: a heal, a buff, a blessing
    "streak",  -- the projectile itself, a comet-headed trail along uAim (its own family so a bolt
               -- in flight and the bolt's impact are visibly one thing)
}

Burst.PATTERNS = {}
for i, name in ipairs(Burst.ORDER) do Burst.PATTERNS[name] = i - 1 end

local defines = {}
for i, name in ipairs(Burst.ORDER) do
    defines[#defines + 1] = string.format("#define B_%s %d", name:upper(), i - 1)
end

Burst.source = table.concat(defines, "\n") .. [[

uniform int   uPattern;
uniform vec4  uTint;
uniform float uAge;
uniform float uSeed;
uniform vec2  uShape;
uniform vec2  uAim;
]] .. Noise.source .. [[

// A 2D rotation, for throwing arcs and shards off uSeed.
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// The birth-and-death envelope every burst rides: a fast rise to 1 near the start of its life, then a
// smooth fall to 0 at the end. `hold` shifts where the peak sits (a low hold snaps then lingers).
float env(float age, float hold) {
    float up = smoothstep(0.0, 0.12, age);
    float dn = 1.0 - smoothstep(hold, 1.0, age);
    return up * dn;
}

// Each family returns vec2(coverage, hot): how much of the pixel it lights, and how much of that is
// the bright core rather than the body -- the same split shaders/field.lua uses, so the composite
// below can share one highlight rule with it.

// p is centred coordinates, roughly -1..1 across the quad. The point of impact is the origin.

vec2 pat_slash(vec2 p, float age) {
    // A blade arc SWUNG from the attacker's side onto the target. Rotate into a frame where +x is the
    // blow's travel (uShape.y is attacker -> victim, so the attacker sits toward -x); a small per-swing
    // jitter keeps repeats from stacking, but the arc always tracks the real strike direction.
    float ang = uShape.y + (uSeed - 0.5) * 0.3;
    p = rot(-ang) * p;
    // A crescent that pivots from behind the attacker's side: an arc of a circle centred toward -x whose
    // radius grows as the swing follows through, so the lit edge sweeps across the point from the near
    // side out past the far side over the burst's life -- a blade arcing FROM the attacker THROUGH the
    // body, not an expanding ring and not a random diagonal. The `front` mask keeps only the
    // target-facing half of that circle (its concave side toward the attacker), which is what reads as a
    // swung blade rather than a full ring closing in.
    vec2  c    = vec2(-0.6, 0.0);
    float R    = 0.6 + age * 0.95;                   // the arc's radius grows as the blow follows through
    float edge = smoothstep(0.14, 0.0, abs(length(p - c) - R));
    float front = smoothstep(-0.1, 0.65, p.x - c.x); // only the leading, target-side stretch of the arc
    float span = smoothstep(1.4, 0.2, length(p));    // fade toward the tile's edges
    float e = env(age, 0.15);
    float arc = edge * front * span * e;
    return vec2(arc, arc);
}

vec2 pat_pierce(vec2 p, float age) {
    float ang = uShape.y;
    p = rot(-ang) * p;
    // A lens along the hit direction: narrow across, driven forward along it, with a hard flash at the
    // puncture the instant it lands.
    float reach = -0.2 + age * 1.1;
    float shaft = smoothstep(0.09, 0.0, abs(p.y)) * smoothstep(reach + 0.1, reach - 0.4, p.x)
                * smoothstep(-0.6, -0.2, p.x);
    float flash = smoothstep(0.35, 0.0, length(p)) * (1.0 - smoothstep(0.0, 0.35, age));
    float e = env(age, 0.2);
    float cover = clamp(shaft * e + flash, 0.0, 1.0);
    return vec2(cover, clamp(flash + shaft * e * 0.6, 0.0, 1.0));
}

vec2 pat_crush(vec2 p, float age) {
    float r = length(p);
    // An expanding shock ring...
    float ring = smoothstep(0.14, 0.0, abs(r - age * 1.05)) * (1.0 - age * 0.6);
    // ...over a low, churning puff of kicked-up dust that lingers after the ring has gone.
    float dust = smoothstep(0.7 + age * 0.4, 0.0, r) * fbm(p * 3.0 + uSeed * 10.0) * (1.0 - smoothstep(0.3, 1.0, age));
    float cover = clamp(ring + dust * 0.5, 0.0, 1.0);
    return vec2(cover, ring);
}

vec2 pat_bloom(vec2 p, float age) {
    float r = length(p);
    vec2 q = p * 2.6;
    q.y -= age * 1.2;                                 // the fire rises as it burns out
    float warp = fbm(q * 0.8 + uSeed * 7.0);
    float n = fbm(q + warp * 0.7);
    float ball = smoothstep(0.75 + age * 0.7, 0.0, r); // a growing, then shrinking, hot volume
    float fire = smoothstep(0.35, 0.75, n) * ball;
    float core = smoothstep(0.5, 0.0, r) * (1.0 - smoothstep(0.0, 0.55, age));
    float e = env(age, 0.25);
    float cover = clamp(fire * e + core, 0.0, 1.0);
    return vec2(cover, clamp(core + fire * e * 0.5, 0.0, 1.0));
}

vec2 pat_shatter(vec2 p, float age) {
    float r = length(p);
    // A hard freezing flash at the point...
    float flash = smoothstep(0.4, 0.0, r) * (1.0 - smoothstep(0.0, 0.25, age));
    // ...flinging a ring of shards outward. Cell noise gives them facets rather than dots.
    vec2 c = cellular2(rot(uSeed * TAU) * p * 3.5 - age * 1.5);
    float seam = smoothstep(0.08, 0.0, c.y - c.x);
    float band = smoothstep(0.2, 0.0, abs(r - age)) ;
    float shards = seam * band;
    float e = env(age, 0.2);
    float cover = clamp(flash + shards * e, 0.0, 1.0);
    return vec2(cover, clamp(flash + shards * e, 0.0, 1.0));
}

vec2 pat_bolt(vec2 p, float age) {
    float ang = uShape.y;
    p = rot(-ang) * p;
    // A vertical fork that jitters along its length; the jitter is frozen per-strike by uSeed.
    float wob = (fbm(vec2(p.y * 4.0 + uSeed * 20.0, uSeed * 5.0)) - 0.5) * 0.5;
    float fil = smoothstep(0.05, 0.0, abs(p.x - wob));
    // Snaps in almost instantly, holds, then cuts out -- lightning does not fade, it stops.
    float on = smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.45, 0.7, age));
    float flash = smoothstep(0.3, 0.0, length(p)) * (1.0 - smoothstep(0.0, 0.2, age));
    float cover = clamp(fil * on + flash, 0.0, 1.0);
    return vec2(cover, cover);
}

vec2 pat_spray(vec2 p, float age) {
    float r = length(p);
    // A soft cloud of droplets expanding and thinning: gas, acid, rot.
    float grow = 0.2 + age * 0.9;
    float body = smoothstep(grow, grow * 0.3, r);
    float speck = fbm(p * 4.5 + uSeed * 12.0 - age);
    float cloud = body * smoothstep(0.35, 0.7, speck);
    float e = env(age, 0.35);
    return vec2(cloud * e, 0.0);                      // no hot core: a puff has no highlight
}

vec2 pat_flare(vec2 p, float age) {
    float r = length(p);
    float ang = atan(p.y, p.x);
    // Rays fanning from the centre, turning slowly; a bright hub over them.
    float rays = 0.5 + 0.5 * sin(ang * 8.0 + uSeed * TAU);
    float fan = pow(rays, 3.0) * smoothstep(0.2 + age, 0.0, r);
    float hub = smoothstep(0.35, 0.0, r);
    float e = env(age, 0.25);
    float cover = clamp((fan * 0.7 + hub) * e, 0.0, 1.0);
    return vec2(cover, cover);
}

vec2 pat_sigil(vec2 p, float age) {
    float r = length(p) * 1.6;
    float ang = atan(p.y, p.x);
    // A ring that snaps open to full radius, holds a moment, then dissolves outward.
    float grow = smoothstep(0.0, 0.3, age);
    float rad = 0.75 * grow;
    float ring = smoothstep(0.09, 0.0, abs(r - rad));
    float ticks = smoothstep(0.5, 1.0, sin(ang * 6.0 - uSeed * TAU)) * smoothstep(0.14, 0.0, abs(r - rad * 0.7));
    float e = env(age, 0.4);
    float cover = clamp((ring + ticks) * e, 0.0, 1.0);
    return vec2(cover, cover);
}

vec2 pat_motes(vec2 p, float age) {
    // Soft points that rise and fade -- a blessing lifting off a body.
    p.y += age * 0.8;                                 // the whole field drifts up
    float n = vnoise(p * 5.0 + vec2(uSeed * 9.0, 0.0));
    float pts = smoothstep(0.82, 0.99, n);
    float body = smoothstep(1.1, 0.1, length(p));     // clustered near the centre
    float e = env(age, 0.3);
    return vec2(pts * body * e, pts * body * e);
}

vec2 pat_streak(vec2 p, float age) {
    // The projectile in flight. uAim is the travel direction; the head leads, a tail trails behind it.
    vec2 dir = length(uAim) > 1e-4 ? normalize(uAim) : vec2(1.0, 0.0);
    vec2 perp = vec2(-dir.y, dir.x);
    float along = dot(p, dir);
    float across = dot(p, perp);
    float head = smoothstep(0.35, 0.0, length(p));    // a bright comet head at the point itself
    // A tail behind the head (negative `along`), narrowing as it recedes.
    float tail = smoothstep(0.9, 0.0, -along) * smoothstep(0.14, 0.0, abs(across) * (1.0 + (-along)))
               * step(along, 0.05);
    float cover = clamp(head + tail * 0.8, 0.0, 1.0);
    return vec2(cover, head);                          // streaks never fade on age: the controller
                                                        // ends them on arrival, uTint.a carries the life
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 p = (tc - 0.5) * 2.0;                         // centre the quad, -1..1
    float age = uAge;

    vec2 v = vec2(0.0);
    if      (uPattern == B_SLASH)   v = pat_slash(p, age);
    else if (uPattern == B_PIERCE)  v = pat_pierce(p, age);
    else if (uPattern == B_CRUSH)   v = pat_crush(p, age);
    else if (uPattern == B_BLOOM)   v = pat_bloom(p, age);
    else if (uPattern == B_SHATTER) v = pat_shatter(p, age);
    else if (uPattern == B_BOLT)    v = pat_bolt(p, age);
    else if (uPattern == B_SPRAY)   v = pat_spray(p, age);
    else if (uPattern == B_FLARE)   v = pat_flare(p, age);
    else if (uPattern == B_SIGIL)   v = pat_sigil(p, age);
    else if (uPattern == B_MOTES)   v = pat_motes(p, age);
    else                            v = pat_streak(p, age);

    float cover = clamp(v.x, 0.0, 1.0) * uShape.x;
    float hot   = clamp(v.y, 0.0, 1.0);
    float a = cover * uTint.a * color.a;
    if (a <= 0.003) discard;

    vec3 rgb = mix(uTint.rgb, min(uTint.rgb * 2.2 + 0.35, vec3(1.0)), hot);
    return vec4(rgb * color.rgb, a);
}
]]

return Burst
