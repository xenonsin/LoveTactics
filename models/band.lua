-- HOW MANY BODIES A STOP FIELDS, AND WHY IT IS NOT A NUMBER.
--
-- Every `composition` in data/encounters wrote its own arithmetic, and it was the same arithmetic
-- fifty-one times over: a base, plus one more body every so many floors, sometimes with a ceiling on
-- it. A hand-copy of one idea in fifty-one files is a thing that drifts -- encounter_boar grew a body
-- PER FLOOR where its neighbours grew one per five, which is not a design decision anybody made, it is
-- what happens when the divisor is typed out each time ([[one-ladder-arithmetic-copies]]).
--
-- So the arithmetic moved here, and on the way it grew the half it never had: a ROLL.
--
-- WHY A ROLL AT ALL. A stop that fields exactly four boars at depth three fields exactly four boars at
-- depth three forever. The player reads the marker once, learns the number, and every later meeting is
-- recall rather than a look at the board. A band is cheap to give and it is the difference between
-- "the boars again" and "how many this time" -- and it costs the fight nothing, because what makes a
-- deep-floor body worse was never the count (data/encounters/encounter_bear.lua argues this in full:
-- what makes a deep bear worse is that it is a deeper-floor bear, minted at the floor's own level).
--
-- ---------------------------------------------------------------------------
-- RATED AT THE MIDDLE, PLAYED ACROSS THE BAND
-- ---------------------------------------------------------------------------
--
-- A composition is resolved four or five times for every once it is fought, and only ONE of those
-- resolutions is the fight:
--
--   models/muster.lua      rates the far side, which is what colours the overworld marker and what
--                          gates the walk-off (Muster.WALK_OVER)
--   models/descent.lua     filters the floor's pool on that rating -- the body floor, the combat
--                          share, and `overCap`, which refuses a fight the floor cannot cut to size
--   models/balance.lua     walks every composition for the balance report
--   models/arena.lua       finally seats it
--
-- A plain `math.random` in a blueprint would make those disagree: a marker priced against one fight
-- and a board that seats another is worse than no marker at all, which is the argument Arena.enemyCap
-- already makes about the tier. So the roll hangs off the FIGHT'S OWN SEED -- the number the board is
-- already reproducible from, stamped onto the ctx by Arena.build -- and every path that has no seed
-- (which is every rating path above) is answered with the band's CENTRE.
--
-- The centre is the number the blueprint used to field outright. So nothing any rating reads has
-- moved, the balance report is as deterministic as it was, and a seed still reproduces a fight body
-- for body.
--
-- ONE ASYMMETRY, STATED RATHER THAN HIDDEN: where a stop's own `max` has already cut the centre, the
-- band is [centre - vary, centre] rather than either side of it -- the ceiling is a ceiling, so the
-- roll can only lighten there. The rating then sits at the TOP of what can be played rather than in
-- the middle of it, which is the safe direction for every guard that reads it: a floor never seats a
-- fight heavier than it priced.
--
-- ---------------------------------------------------------------------------
-- AND THE TIER'S CEILING IS STILL THE TIER'S CEILING
-- ---------------------------------------------------------------------------
--
-- Nothing here knows about Arena.SKIRMISH_CAP (4) or ELITE_CAP (6), and it must not: the clamp is one
-- rule in one place (Arena.clampComposition) and a second copy of it here could only ever disagree.
--
-- What that means for a band is worth saying out loud, because it is not obvious: a stop whose centre
-- is already ABOVE its tier's ceiling rolls entirely underneath the clamp, and the player sees the
-- ceiling every time. The roll is not lost, it is unreadable -- which is the clamp telling you the
-- stop was authored above its own tier. Where that is true and deliberate (a swarm is meant to arrive
-- at the ceiling), leave it; where it is an accident of a divisor, the fix is the count, not the band.
--
-- Pure arithmetic over models/seed.lua. No love, no state, headless.

local Seed = require("models.seed")

local Band = {}

-- HOW WIDE A BAND IS BY DEFAULT, in bodies either side of the centre.
--
-- One, and the reason is the ceiling above. A skirmish seats four; a band of +/-2 on a centre of three
-- would roll one body against a party of four, which is not a lighter fight, it is a different stop.
-- One body either side is the most a four-body fight has room to vary by and still be the fight the
-- marker promised.
Band.VARY = 1

-- THE COUNT, resolved for this ctx.
--
--   spec.base   how many at the shallow end. Required in practice; 1 if omitted.
--   spec.per    one more body every `per` floors. Omitted = the count does not grow with depth, which
--               is the right answer more often than it looks (see the module header).
--   spec.vary   half-width of the band. Band.VARY unless a blueprint has a reason.
--   spec.max    a ceiling of the stop's OWN, applied before the band is taken -- a bear is not a herd
--               animal and never becomes one. Not the tier's ceiling, which is Arena's.
--   spec.min    a floor, default 1. A stop that rolls nobody is a stop that is not there.
--   spec.key    what the roll is taken against, so two fills in one composition do not move together.
--               Band.fill passes the body's own id and nothing else needs to.
function Band.count(ctx, spec)
    ctx, spec = ctx or {}, spec or {}
    local depth = ctx.depth or 1

    local n = spec.base or 1
    if spec.per then n = n + math.floor(depth / spec.per) end
    -- The stop's own ceiling first, so the band is taken around what it will actually field rather
    -- than around a number it was never going to reach.
    if spec.max then n = math.min(n, spec.max) end

    local vary = spec.vary or Band.VARY
    local lo = math.max(spec.min or 1, n - vary)
    local hi = n + vary
    if spec.max then hi = math.min(hi, spec.max) end
    if hi < lo then hi = lo end
    if n < lo then n = lo elseif n > hi then n = hi end

    -- NO SEED, NO ROLL: every rating path lands here, and it must land on the centre. See the header.
    if not ctx.seed then return n end

    -- Folded with the depth as well as the body, so the same stop met on two floors of one circle is
    -- not the same draw twice -- and with the base, so two bodies sharing a key by accident still part.
    local roll = Seed.mix(ctx.seed, Seed.text(spec.key or ""), spec.base or 0, depth)

    -- SCALED, NOT MODDED, and that is not a style preference -- `roll % 3` shipped here first and was
    -- caught by tests/encounter_spec.lua on the Meandering Stag, which rolled the SAME escort on all
    -- forty seeds it was asked for.
    --
    -- Seed.mix ends on `% Seed.SPAN`, a power of ten, so the value's low digits carry whatever
    -- structure survived the mixing while its high ones are the well-spread half. Taking a remainder
    -- reads the bad end; scaling across the span reads the good one. This is
    -- [[linear-hash-per-iteration-is-not-a-roll]] wearing its other face: a hash that is fine as an
    -- identity can still be worthless as a die if you ask it for the wrong bits.
    return lo + math.floor(roll * (hi - lo + 1) / Seed.SPAN)
end

-- Append the rolled count of `id` to `list`, and hand `list` back so a composition reads as one line
-- per body. The body's id is the roll's key, so the two halves of a mixed stop roll apart.
function Band.fill(list, ctx, id, spec)
    spec = spec or {}
    if spec.key == nil then
        -- A copy rather than a write: blueprints hand the same literal table in on every call, and
        -- stamping a key into it would be stamping it into the blueprint.
        local s = { base = spec.base, per = spec.per, vary = spec.vary,
            max = spec.max, min = spec.min, key = id }
        spec = s
    end
    for _ = 1, Band.count(ctx, spec) do list[#list + 1] = id end
    return list
end

return Band
