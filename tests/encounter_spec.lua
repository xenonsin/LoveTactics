-- Tests for dynamic encounter selection (models/encounter.lua): prestige gating,
-- weight scaling, and conditional (biome) eligibility.

local Encounter = require("models.encounter")
local Arena = require("models.arena")
local Band = require("models.band")

-- THE FLOORS OF THE RIFT, which is the whole domain a composition is ever resolved over
-- (Descent.FLOORS). Written out rather than required so this file stays a data-layer spec.
local FLOORS = 15

-- The CAST a stop can field: its distinct character ids, sorted and joined, unioned over every depth
-- it could be met at. Sorted because a cast is a set -- two stops that field the same bodies in the
-- other order are the same two fights.
local function castOf(def, depth)
    local seen, ids = {}, {}
    local lo, hi = depth or 1, depth or FLOORS
    if not depth then lo = 1 end
    for d = lo, hi do
        for _, id in ipairs(Arena.resolveComposition(def.composition, { depth = d })) do
            if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
    end
    table.sort(ids)
    return table.concat(ids, " + ")
end

local function withComposition()
    local out = {}
    for id, def in pairs(Encounter.defs) do
        if def.composition then out[#out + 1] = { id = id, def = def } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function has(pool, id)
    for _, e in ipairs(pool) do
        if e.id == id then return e end
    end
    return nil
end

return {
    {
        name = "encounter registry discovers def files by filename",
        fn = function()
            -- It named encounter_elite, which was the Phoenix and went with the human sweep
            -- (92ff549d). Any two real files prove discovery; these are one of each kind, so a
            -- registry that somehow found only the combats would still be caught.
            assert(Encounter.defs.encounter_boar, "boar missing")
            assert(Encounter.defs.encounter_white_wolf, "white wolf missing")
        end,
    },
    {
        name = "a floor gates the encounters that are deeper than it",
        fn = function()
            -- THE GATE IS DEPTH, not a campaign day. The Phoenix opens on floor one now -- the day-two
            -- gate it carried converted to depth one -- so what this case pins is the SHAPE of the gate
            -- rather than that particular blueprint: something deep is refused up here and the wood's
            -- own opener is not.
            local p1 = Encounter.pool({ depth = 1, biome = "forest" })
            assert(not has(p1, "encounter_the_skeleton_king"),
                "a floor-twelve body should be gated on floor one")
            assert(has(p1, "encounter_wolf"), "the wolves are the wood's own, from the first floor")
        end,
    },
    {
        -- NO SHIPPED BLUEPRINT CARRIES A FUNCTION WEIGHT ANY MORE, and that is why this case injects
        -- one. The Phoenix was the only `weight = function(ctx)` in the data and it went with the human
        -- sweep (92ff549d), which left `weightOf`'s function branch live in models/encounter.lua with
        -- nothing exercising it -- a code path that can rot silently and a ceiling nobody re-derives.
        -- The saturating shape is the rule worth keeping, so it is restated here as a fixture and
        -- registered for the length of the case: the Phoenix's own `min(3, depth)`, verbatim.
        --
        -- The pool-share assertion at the foot still reads the REAL pool, so what an elite is worth
        -- against the wood's ordinary fights is measured on shipped data and not on this fixture.
        name = "dynamic weight scales with depth, and then stops",
        fn = function()
            local id = "encounter__weight_probe"
            Encounter.defs[id] = {
                name = "Weight Probe", kind = "elite", depth = 1, biome = "forest",
                weight = function(ctx) return math.min(3, ctx.depth or 1) end,
                composition = function() return { "character_boar" } end,
            }
            local ok, err = pcall(function()
            local function eliteAt(p)
                return has(Encounter.pool({ depth = p, biome = "forest" }), id)
            end
            local e2, e3 = eliteAt(2), eliteAt(3)
            assert(e2 and e2.weight == 2, "elite weight should track prestige while it climbs (2)")
            assert(e3 and e3.weight == 3, "elite weight should track prestige while it climbs (3)")

            -- THE CEILING IS THE POINT, and it is what this case is really for. The weight was
            -- `ctx.prestige` unbounded, against the fixed 4-6 an ordinary road fight carries, so past
            -- prestige ~6 the elite stopped being the tough fight and became the only fight -- measured
            -- at 76% of every board's combats (`. board-report`). An elite that is the ordinary case
            -- has nothing to be an elite against, and it flattens the board's whole difficulty arc,
            -- since Overworld:assignEncounterTiers reads rank as a step above depth.
            local e20, e50 = eliteAt(20), eliteAt(50)
            assert(e20 and e20.weight == 3, "elite weight must saturate, not climb with the campaign")
            assert(e50 and e50.weight == e20.weight, "and stay saturated however long the campaign runs")

            -- The saturated elite must stay a MINORITY of the pool's fight weight, which is the
            -- property the tier arc actually depends on. Asserted against the ordinary fights rather
            -- than against a literal, so retuning either side keeps this honest.
            local pool = Encounter.pool({ day = 20, biome = "forest" })
            local ordinary, elite = 0, 0
            for _, e in ipairs(pool) do
                if e.kind == "combat" then ordinary = ordinary + e.weight
                elseif e.kind == "elite" then elite = elite + e.weight end
            end
            assert(elite < ordinary / 2,
                string.format("elites must stay the exception on the road (elite %d vs combat %d)",
                    elite, ordinary))
            end)
            Encounter.defs[id] = nil
            assert(ok, err)
        end,
    },
    {
        name = "conditional encounter respects biome",
        fn = function()
            -- THE STAG WAS LOCKED TO THE CASTLE, WHICH WAS ALWAYS ODD, and the circle-lock rule has
            -- since settled it: humans float to every floor and everything else belongs to exactly one
            -- circle. A stag is a beast, the beasts are Gluttony's, and Gluttony holds the wood.
            local forest = Encounter.pool({ day = 3, biome = "forest" })
            local castle = Encounter.pool({ day = 3, biome = "castle" })
            assert(has(forest, "encounter_the_herd"), "stags should roam the wood")
            assert(not has(castle, "encounter_the_herd"), "a beast has no business in Lust's hall")
        end,
    },

    {
        name = "no two encounters field the same cast",
        fn = function()
            -- ONE CAST, ONE STOP. Two blueprints that field the same bodies at two counts are not two
            -- fights -- they are one fight the player meets twice under two names, and the count is
            -- invisible from the tile: Arena.clampComposition cuts both to the same tier ceiling, so a
            -- stop authored at `3 + depth/5` and one authored at `2 + depth` both seat four bodies.
            --
            -- FIVE SHIPPED, AND FOUR BLUEPRINTS WERE DELETED RATHER THAN DIFFERENTIATED:
            --
            --   encounter_the_sounder   boars beside encounter_boar's boars
            --   encounter_stag          a lone Ancient Stag beside encounter_the_herd's
            --   encounter_siege_pickets / _line / _breach
            --                           two casts shared with the prologue's own measured stops, on
            --                           three blueprints no player could reach (their quest is gone)
            --
            -- The fifth pair was answered in place: encounter_wolf gave up the alpha it had grown,
            -- which restored a sentence encounter_wolf_pack and three other files already made.
            --
            -- ASSERTED OVER THE WHOLE TABLE rather than over a sample, because the failure being
            -- guarded is a NEW blueprint arriving beside an old one, and a sample cannot see a pair it
            -- does not name.
            --
            -- ASSERTED OVER THE WHOLE TABLE rather than over a sample, because the failure being
            -- guarded is a NEW blueprint arriving beside an old one, and a sample cannot see a pair it
            -- does not name.
            local byCast = {}
            for _, e in ipairs(withComposition()) do
                local cast = castOf(e.def)
                assert(cast ~= "", e.id .. " fields nobody at any depth")
                assert(not byCast[cast], string.format(
                    "%s and %s field the same cast (%s) -- one cast, one stop. Give one of them a "
                    .. "different body; a different COUNT is not a different fight.",
                    byCast[cast] or "?", e.id, cast))
                byCast[cast] = e.id
            end
        end,
    },
    {
        name = "and they do not collide on any single floor either, count aside",
        fn = function()
            -- The case above unions a stop's cast over all fifteen floors, which is the right question
            -- about a blueprint. This is the question about a BOARD: two stops can carry different
            -- casts overall and still be indistinguishable on the floor you are standing on -- the
            -- Bone Orchard grows a bow at depth fourteen and is skeleton knights alone before that.
            for depth = 1, FLOORS do
                local byCast = {}
                for _, e in ipairs(withComposition()) do
                    local cast = castOf(e.def, depth)
                    assert(not byCast[cast], string.format(
                        "on floor %d, %s and %s both field %s", depth, byCast[cast] or "?", e.id, cast))
                    byCast[cast] = e.id
                end
            end
        end,
    },
    {
        name = "a stop fields a band of bodies, rolled off the fight's own seed",
        fn = function()
            -- HOW MANY IS NOT A CONSTANT. Every rolled stop draws its filler count from models/band.lua
            -- against the seed Arena.build stamps onto the ctx, so the same stop met twice is not the
            -- same head-count twice.
            --
            -- THE PINNED FIVE ARE NAMED, not described, and each one carries its reason in its own
            -- blueprint. A named list is the point: a stop that quietly stops rolling -- an author
            -- writing a literal count, or a band whose `max` swallows it -- would otherwise join them
            -- silently, and "most stops vary" is not a property anybody can check.
            local PINNED = {
                -- Two measurements facing each other with one number between them; a lighter shoal ran
                -- 33 unit-turns against a budget of 22.
                encounter_the_shoal = true,
                -- The prologue's two objective lessons, timed tick by tick against a two-body party.
                encounter_survivors_defend = true,
                encounter_survivors_extract = true,
                -- A cast of one, and the only plain-table composition in the game: two mimics is two
                -- chests, standing in two places. The disguise is the entire monster.
                encounter_mimic = true,
                -- A cast of one that is three bodies: the Chimera grows its own two heads at the bell,
                -- and anything standing beside it would stand in the goat's cone.
                encounter_the_chimera = true,
            }
            -- THE ROSTER, NOT THE HEAD-COUNT. Asked as "is this the same fight on every seed", because
            -- a stop is allowed to roll its SHAPE while holding its size: the Skeleton King's court is
            -- always three subjects (his opening mana is thirty a head and the header calls that
            -- number the fight's first sentence) and what rolls is how many of them carry bows. A
            -- count-only check would file that under pinned and stop watching it.
            for _, e in ipairs(withComposition()) do
                local rosters, n = {}, 0
                for seed = 1, 40 do
                    local ids = Arena.resolveComposition(e.def.composition, { depth = 8, seed = seed })
                    local sorted = {}
                    for i, id in ipairs(ids) do sorted[i] = id end
                    table.sort(sorted)
                    local key = table.concat(sorted, ",")
                    if not rosters[key] then rosters[key] = true; n = n + 1 end
                end
                if PINNED[e.id] then
                    assert(n == 1, e.id .. " is on the pinned list but its roster moves -- either it "
                        .. "rolls now, in which case take it off the list, or something else changed")
                else
                    assert(n > 1, e.id .. " fields the same bodies on every seed. Give it a band "
                        .. "(models/band.lua), or pin it HERE with the reason in its own blueprint.")
                end
            end
        end,
    },
    {
        name = "rated at the middle, played across the band",
        fn = function()
            -- THE LAW THE RATING PATHS DEPEND ON. models/muster.lua colours the overworld marker and
            -- gates the walk-off; Descent.floorPool drops a fight under the floor's median worth and
            -- refuses one it cannot cut to size; the balance report walks every composition. None of
            -- them holds a seed, and all of them must get the same answer every time -- so a seedless
            -- ctx resolves the band's CENTRE, and the centre sits inside what play can roll.
            for _, e in ipairs(withComposition()) do
                local unseeded = #Arena.resolveComposition(e.def.composition, { depth = 8 })
                local again = #Arena.resolveComposition(e.def.composition, { depth = 8 })
                assert(unseeded == again, e.id .. " answers a seedless ctx differently twice -- a "
                    .. "rating that is not reproducible is not a rating")

                local lo, hi = math.huge, 0
                for seed = 1, 40 do
                    local n = #Arena.resolveComposition(e.def.composition, { depth = 8, seed = seed })
                    lo, hi = math.min(lo, n), math.max(hi, n)
                end
                assert(unseeded >= lo and unseeded <= hi, string.format(
                    "%s rates at %d but plays between %d and %d -- the centre has drifted out of its "
                    .. "own band", e.id, unseeded, lo, hi))
            end
        end,
    },
    {
        name = "the band's edges hold: a stop never rolls nobody, and never past its own ceiling",
        fn = function()
            -- Band.count's two clamps, asserted directly rather than only through the blueprints that
            -- happen to use them today. A stop that rolls zero bodies is a stop that is not there
            -- (Descent.MIN_BODIES would drop it, but only after it had been seated), and a `max` is a
            -- blueprint's own statement about its animal -- a bear is not a herd animal and never
            -- becomes one -- which the band may not roll past in either direction.
            for seed = 1, 60 do
                local one = Band.count({ depth = 1, seed = seed }, { base = 1 })
                assert(one >= 1, "a band rolled " .. one .. " bodies")

                local capped = Band.count({ depth = 15, seed = seed }, { base = 2, per = 2, max = 4 })
                assert(capped <= 4, "a band rolled " .. capped .. " past its own max of 4")
                assert(capped >= 3, "a capped band collapsed to " .. capped)
            end

            -- `vary = 0` is the documented way out, and it must be exact rather than nearly exact.
            for seed = 1, 60 do
                assert(Band.count({ depth = 7, seed = seed }, { base = 3, vary = 0 }) == 3,
                    "vary = 0 must field the authored count, seed or no seed")
            end

            -- ...AND A BAND MUST ACTUALLY REACH BOTH EDGES. This is the case that earns its keep: the
            -- first cut of Band.count took `Seed.mix(...) % range`, and Seed.mix ends on a power of
            -- ten, so the remainder read the value's LOW digits -- the half of it the mixing leaves
            -- structured. A three-wide band answered one number on forty consecutive seeds and looked
            -- exactly like a stop somebody had pinned on purpose. Asserted as coverage of the whole
            -- band rather than as "it varies", because a die stuck on two of three faces is still a
            -- die that varies ([[linear-hash-per-iteration-is-not-a-roll]]).
            for _, spec in ipairs({ { base = 3 }, { base = 2, per = 5 }, { base = 4, min = 3 } }) do
                for _, key in ipairs({ "character_boar", "character_wolf_grunt", "" }) do
                    local hit, faces = {}, 0
                    local lo, hi = math.huge, 0
                    for seed = 1, 60 do
                        local n = Band.count({ depth = 6, seed = seed },
                            { base = spec.base, per = spec.per, min = spec.min, key = key })
                        if not hit[n] then hit[n] = true; faces = faces + 1 end
                        lo, hi = math.min(lo, n), math.max(hi, n)
                    end
                    assert(faces == 3 and hi - lo == 2, string.format(
                        "a +/-1 band reached %d of its 3 values over 60 seeds (base %d, key %q) -- the "
                        .. "roll is reading the wrong end of the hash", faces, spec.base, key))
                end
            end

            -- And the roll is a function of the seed and nothing else: same seed, same board, same
            -- bodies. This is what makes a shared seed reproduce a fight rather than merely a map.
            for seed = 1, 20 do
                local spec = { base = 3, per = 4, key = "character_wolf_grunt" }
                assert(Band.count({ depth = 9, seed = seed }, spec)
                    == Band.count({ depth = 9, seed = seed }, spec),
                    "the same seed must roll the same count")
            end
        end,
    },
    {
        name = "opensBattle answers for the ends and the errands, not only the rolled fights",
        fn = function()
            -- THE MARKER'S PROMISE, in table form. ui/overworld_map.lua draws one shared combat border
            -- on everything this says yes to, so a kind that drifts out of it stops looking like a fight
            -- while still being one -- which is precisely the state the errands were in.
            for _, enc in ipairs({
                { kind = "combat" },
                { kind = "elite" },
                { kind = "objective" },                                 -- the floor's own end
                { kind = "objective", questId = "quest_bastion_slot_01" }, -- an errand: an end that is a job
                { kind = "pack", composition = { "character_wolf" } },  -- the pile with something on it
            }) do
                assert(Encounter.opensBattle(enc),
                    (enc.kind or "?") .. " opens the arena and must wear the combat border")
            end

            -- ...and the two exceptions kind alone cannot see. A `meet` end is walked onto, not fought
            -- (the arena debut), and a pack dropped before the guard rule existed is a pickup.
            assert(not Encounter.opensBattle({ kind = "objective", meet = true }),
                "a meet end is a walk-out; promising a fight there is a lie the player walks into")
            assert(not Encounter.opensBattle({ kind = "pack" }),
                "an unguarded pack is a pickup")

            -- Nothing else on the board, and this list is the whole of the rest of markerColor's kinds.
            -- Asserted as a set rather than a sample, because the failure being guarded is a kind
            -- quietly joining the fights, and a sample cannot see one it does not name.
            for _, kind in ipairs({ "treasure", "event", "rest", "relic_cache", "shrine",
                                    "merchant", "crossroads", "ascent", "stair", "anvil",
                                    "weeping_stone", "dark", "spinner", "translation" }) do
                assert(not Encounter.opensBattle({ kind = kind }),
                    kind .. " is not a fight and must not wear the combat border")
            end

            assert(not Encounter.opensBattle(nil), "an empty tile is not a fight")
        end,
    },

    {
        name = "nobody restates the fight test beside the one that draws the border",
        fn = function()
            -- A SOURCE SCAN, because the defect this guards is a SECOND COPY rather than a wrong answer.
            -- The border and the battle branch were one question asked in two places, and the way that
            -- goes wrong is not that either is mistaken today -- it is that a kind is added to one of
            -- them a year from now. states/game.lua held `kind == "combat" or kind == "elite" or kind ==
            -- "objective"` twice; both read through Encounter.opensBattle now, and this fails if a third
            -- copy is written.
            --
            -- Scoped to the two files that own the question. models/overworld.lua tests the same kinds
            -- all over the generator and is right to: seating, guarding and tiering a fight are
            -- placement questions, asked before an encounter is a stop the player can walk onto.
            --
            -- `objective` IS THE TERM SCANNED FOR, and that is what makes the scan mean something rather
            -- than merely fire. Testing combat-and-elite together is common and usually correct --
            -- ui/overworld_map.lua's pipSteps does it and deliberately leaves the ends out, because a
            -- muster cannot price an escort. What says "this line is asking whether the arena opens" is
            -- the ends being IN, which is the exact clause the errands were missing from the border.
            for _, path in ipairs({ "states/game.lua", "ui/overworld_map.lua" }) do
                local f = assert(io.open(path, "r"), "cannot read " .. path)
                local src = f:read("*a"); f:close()
                local n = 0
                for line in src:gmatch("[^\n]+") do
                    n = n + 1
                    -- The notes quote the old test on purpose -- that is how they explain themselves --
                    -- so a line that is entirely a comment is not code and does not count.
                    if not line:match("^%s*%-%-") then
                        assert(not (line:match('"combat"') and line:match('"elite"')
                            and line:match('"objective"')), string.format(
                            "%s:%d restates the fight test; ask Encounter.opensBattle so the border "
                            .. "cannot drift from the branch that runs the battle", path, n))
                    end
                end
            end
        end,
    },
}
