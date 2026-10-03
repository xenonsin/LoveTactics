-- EVERY FLOOR FIELDS GLUTTONY'S VARIETY OF CREATURES, and the ones that do not yet are named.
--
-- Settled 2026-09-25: Gluttony is the benchmark, and what is measured is CREATURE variety -- how many
-- distinct creatures a floor can put in front of a company -- not unit count, which Lust and Greed already
-- exceed, and not the number of fights, which a new lineup of old creatures can raise without the floor
-- looking any different. A floor is within spec when it fields at least 15 distinct creatures across every
-- ordinary fight and elite it can deal: Gluttony's first floor exactly (its stair floor fields 18).
--
-- A CREATURE IS A BODY THAT FIGHTS. Objects are not counted -- a Dragon Egg, a Scarab Egg, a banner
-- (`race = "object"`, or tier 0) -- because a floor with three kinds of egg on it has not grown three
-- kinds of enemy.
--
-- Measured through Descent.floorPool on a walked rift -- the wiring, not the blueprints -- and keyed by
-- CIRCLE and RUNG rather than by floor number, so a reshuffled circle order cannot move a gap onto the
-- wrong row.
--
-- AND NOW FIGHTS AND ELITES ARE HELD TOO (approved on review 2026-09-26, variety round 1). Creatures alone
-- let Lust's approach pass at 17 while it dealt six ordinary fights, because five of its bodies stood in
-- elites a floor sees one or two of. So two more floors sit beside the first: at least FIGHT_SPEC
-- EFFECTIVE ordinary fights -- inverse Simpson over the deal weights floorPool hands out, so a stray at its
-- 15% share counts for about that much and a fight the median filter dropped counts for nothing -- and at
-- least ELITE_SPEC distinct elites the floor can seat. A new lineup of old creatures does raise the first
-- number without growing the bestiary; that is the point of it, since a floor where every stop is the same
-- stop reads as thin however many creatures are in it.
--
-- THE KNOWN GAPS ARE A RATCHET, NOT A WAIVER. A circle-rung listed below is allowed to miss the spec, and
-- must miss it: the day it reaches spec the build fails until its line comes off. A circle-rung that is not
-- listed and falls below spec fails the build. The values are what the floor measured when the line was
-- written, so the list doubles as the work queue.
--
-- THE BRIEFS FOR THE CIRCLES STILL OWED (2026-09-26). What each empty circle is ABOUT, so the bodies that
-- fill it are picked for the sin and not just to make the count. The themes and the first roster of each
-- are the author's; a line marked "suggested" is a proposal to be taken or struck, not a decision.
--
--   GLUTTONY -- THE BENCHMARK, not owed; written here because docs/story.md's Hunter's Lodge reading is out of
--     date and this list is where a circle's brief is read from (the author's, 2026-09-29).
--     Themes: survival of the fittest, apex predator, beasts, the hunt, hunger, insatiable, wastefulness.
--     Bodies: the wood's beasts -- wolves, boars and bears, hawks and the griffin, sabertooths, stags, giant
--       spiders, manticores, wyverns, the giant toad, moss slimes, the chimera -- under the Sated and Gula,
--       the apex who eats them and does what they did.
--     Its own stops (not fights, 2026-09-29): the Carcass, the Watering Hole, the Maw.
--
--   WRATH -- anger, relentlessness, no control, fury, raging fire, raging water, disaster, blindness,
--     passion that overwhelms reason, the trap.
--     Bodies: goblins, trolls, orcs, ogres, minotaurs, oni, vengeful spirits, ghosts, vampires.
--     DONE: the goblins (2026-09-26, "The Goblins of Wrath", tests/goblin_line_spec.lua) -- a race with Blood
--       Feud, eleven bodies from the Cutter to the Goblin King, six fights.
--     DONE: the orcs (2026-09-26, "The Orcs of Wrath", tests/orc_line_spec.lua) -- a race made Proven by every
--       kill, nine bodies and a War Ogre, ten fights with two of them mixed with goblins.
--     DONE (core): the vampires (2026-09-26, "The Vampires of Wrath", tests/vampire_spec.lua) -- a TAG on race and
--       class with the Thirst, a living thrall and a bat, five vampires and the Sire, seven fights.
--       The rest are still owed.
--     Suggested: berserkers, furies (the Erinyes -- vengeance with a name), hellhounds, salamanders.
--     Mechanic ideas (suggested): a body that cannot stop attacking once started; a rage that grows with
--       every hit TAKEN; blindness that makes a swing land on whatever is nearest, friend or foe; floods
--       and fires that spread on their own; a trap that a charging body cannot refuse to walk into.
--
--   ENVY -- BUILT 2026-10-03 ("Envy's Bestiary", three rounds). The Faceless (A Thousand Faces: they wear any
--     character in the game) and the Water Mirror on the seat, with the Homunculus, the Brazen Head, Echo, Arachne
--     and the Sewn-Eyed; the Evil Eye, the Mirage, the Patchwork, the Shade, the Jackal Weighers, the Green-Eyed
--     Monster and the Sand-Eels on the approach; Medusa and the Kinslayer as elites; Leviathan on the lieutenant's
--     stair and the Many Faced One on the general's; any non-combat stop on the waste may be a Mimic. The brief as
--     it was written:
--   ENVY -- mirrors, illusions, copying, fear, jealousy, comparison, deception, betrayal, suffering,
--     resentment, isolation, corruption.
--     Bodies: doppelgangers, changelings, the faceless, alchemy, and mimics filling most fights.
--     Suggested: homunculi (alchemy's own child), shades that wear your shadow, fetches (the folklore
--       double seen before a death), a green hag, skin-thieves, mirror-knights, illusionists, lampreys
--       and leeches (what you have, taken), cuckoos (a nest that is somebody else's).
--     Mechanic ideas (suggested): copy the last ability used against it; swap a stat with its target;
--       steal a boon off an ally; illusory duplicates only one of which is real; turn a party member for
--       a turn (betrayal); stronger against a body with no ally beside it (isolation).
--
--   PRIDE -- BUILT 2026-09-30 ("Pride's Bestiary", four rounds of review). The elves (Unblemished), the lions,
--     the masterless djinn and the Peacock-Basilisk and Titan on the approach; the angels (Incorruptible) on the
--     seat; the Elf-Lord, the Unicorn and the Sphinx, the Throne, the Wishmaker, the Phoenix and the Tower-Giant
--     as elites. The brief as it was written:
--   PRIDE -- perfection, superiority, rejection, rebellion, self-importance, ego, ambition, the
--     justified, no repentance, fame.
--     Bodies: elves, angels.
--     Suggested: fallen angels, thrones and ophanim (the wheels), gargoyles and marble saints (idols of
--       the self), a sphinx, unicorns (reject the unworthy), a phoenix (never repents, only returns),
--       titans and giants, templars and duellists (the famous), peacock-basilisks (the gaze that is
--       admired).
--     Mechanic ideas (suggested): strongest at full health and diminished the first time struck
--       (perfection); refuses heals and boons from its own side (rejection); harder to hurt from a
--       lower level (superiority); a duel's challenge it will not decline; a rebel that turns on its own
--       commander when outranked.
--
--   SLOTH -- refusing to act, taxing, pacifism, sleep, laziness, wastefulness, passivity, apathy,
--     indifference, fear, no commitment.
--     Bodies (all suggested): the giant ground sloth, snails and slugs, tortoises, dormice, myconids and
--       spore-caps (a sleep that is breathed), lotus-eaters, a sleeping giant, treants and dryads (rooted),
--       mummies and bog bodies, a sandman or poppy-moths, drones of a hive that does not work, ticks
--       (the host does the work), a possum that plays dead, tollkeepers (the tax).
--     Mechanic ideas (suggested): a body harmless until woken, and worse for it; a sleep aura that
--       spreads to whoever stands still; a toll that taxes a move or an action rather than gold; a
--       pacifist that never attacks but must still be got past; a body that banks the turns it skips;
--       a body that walks away the moment it is engaged (no commitment).

local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Player = require("models.player")
local Character = require("models.character")

local SPEC = 15 -- distinct creatures per floor

-- circle/rung -> what it fielded when listed: the circles the 2026-09-22 cuts emptied, owed their
-- creatures one circle at a time. (Greed's first floor was listed at 12 and closed at 16 with the beetles;
-- Wrath's seat was listed at 6 and closed at 15 with the goblins; its approach closed at 17 with the orcs.
-- Pride's two floors were listed at 5 each and closed on 2026-09-30 at 18 and 23 with the elves, lions and
-- djinn on the approach and the angels on the seat, which also took both floors past FIGHT_SPEC. Envy's two
-- floors were listed at 4 and 6 and re-measured on 2026-10-03 after "Envy's Bestiary": the seat closed at 27
-- creatures, 11.8 effective fights and 5 elites; the approach closed its fights at 7.0 and its elites at 4 and
-- stands at 13 creatures.)
local KNOWN_GAPS = {
    ["sloth/1"] = "3 creatures",
    ["sloth/2"] = "5 creatures",
    -- Envy's approach after its bestiary (2026-10-03): 10 families against Gluttony's 9, but two bodies short on
    -- the body count -- its one-offs come in ones. Re-measured, not closed; the seat closed at 27.
    ["envy/1"]  = "13 creatures",
    ["crown/1"] = "4 creatures -- the bottom floor",
}

local function isCreature(id)
    local def = Character.defs[id]
    return def ~= nil and (def.tier or 0) > 0 and def.race ~= "object"
end

local FIGHT_SPEC = 7.0 -- effective ordinary fights per floor (Gluttony's approach measures 7.8)
local ELITE_SPEC = 4 -- distinct elites a floor can seat (Gluttony's seat has 4)

-- circle/rung -> what it measured when listed. Same ratchet as KNOWN_GAPS.
-- (Greed's two floors were listed at 3 elites each and closed on 2026-09-26: the Paymaster on the approach,
-- the Thing Under the Seam and the Gilded King on the seat.)
local KNOWN_FIGHT_GAPS = {
    ["sloth/1"] = "0 -- no ordinary fight at all",
    ["sloth/2"] = "0 -- no ordinary fight at all",
    ["crown/1"] = "1.0 effective fights -- the bottom floor",
}
local KNOWN_ELITE_GAPS = {
    ["sloth/1"] = "1 elite",
    ["sloth/2"] = "2 elites",
    ["crown/1"] = "2 elites -- the bottom floor",
}

-- What a floor can field, read off the same pool the floor deals from: its distinct creatures, its
-- effective ordinary fights, and its distinct elites.
local function measure(ctx)
    local seen, n = {}, 0
    local weights, total, elites = {}, 0, 0
    for _, e in ipairs(Descent.floorPool(ctx)) do
        if e.kind == "combat" or e.kind == "elite" then
            local comp = Encounter.get(e.id).composition
            local ids = type(comp) == "function" and comp(ctx) or comp or {}
            for _, id in ipairs(ids) do
                if isCreature(id) and not seen[id] then seen[id], n = true, n + 1 end
            end
            if e.kind == "elite" then
                elites = elites + 1
            elseif (e.weight or 0) > 0 then
                weights[#weights + 1] = e.weight
                total = total + e.weight
            end
        end
    end
    local sumSq = 0
    for _, w in ipairs(weights) do sumSq = sumSq + (w / total) ^ 2 end
    return n, (sumSq > 0 and 1 / sumSq or 0), elites
end

local function walk()
    local player = Player.new()
    local run = Descent.new(player, 1)
    local out = {}
    for floor = 1, Descent.FLOORS do
        run.floor = floor
        local quest = Descent.floorQuest(run, player)
        local rung = Descent.floorWithinCircle(floor)
        local ctx = { depth = floor, rung = rung, biome = quest.map.biome, quest = quest,
                      floorLevel = quest.floorLevel, enemyLevel = quest.dangerLevel }
        local key = string.format("%s/%d", tostring(quest.sin or "crown"), rung)
        local n, fights, elites = measure(ctx)
        out[#out + 1] = { floor = floor, key = key, n = n, fights = fights, elites = elites }
    end
    return out
end

local function show(f)
    return string.format("floor %d (%s): %d creatures, %.1f effective fights, %d elites",
        f.floor, f.key, f.n, f.fights, f.elites)
end

-- The ratchet, once per measure: below spec must be listed, and listed must be below spec.
local function ratchet(what, field, spec, known, listName)
    return {
        { name = "every floor deals Gluttony's variety of " .. what .. ", or is on " .. listName, fn = function()
            local bad = {}
            for _, f in ipairs(walk()) do
                if f[field] < spec and not known[f.key] then
                    bad[#bad + 1] = show(f) .. " -- below spec and not a known gap"
                end
            end
            assert(#bad == 0, "floors short of " .. spec .. " " .. what .. ":\n  " .. table.concat(bad, "\n  "))
        end },
        { name = "a closed gap in " .. what .. " comes off " .. listName, fn = function()
            local keys, closed = {}, {}
            for _, f in ipairs(walk()) do
                keys[f.key] = true
                if known[f.key] and f[field] >= spec then
                    closed[#closed + 1] = show(f) .. " -- now within spec; take its line off " .. listName
                end
            end
            for key in pairs(known) do
                assert(keys[key], listName .. " names " .. key .. ", which no floor of the rift is")
            end
            assert(#closed == 0, table.concat(closed, "\n  "))
        end },
    }
end

local cases = {
    { name = "the benchmark passes its own fight and elite specs: both of Gluttony's floors", fn = function()
        for _, f in ipairs(walk()) do
            if f.key == "gluttony/1" or f.key == "gluttony/2" then
                assert(f.fights >= FIGHT_SPEC and f.elites >= ELITE_SPEC,
                    "the benchmark fails the spec it sets: " .. show(f))
            end
        end
    end },
}
for _, c in ipairs(ratchet("effective ordinary fights", "fights", FIGHT_SPEC, KNOWN_FIGHT_GAPS, "KNOWN_FIGHT_GAPS")) do
    cases[#cases + 1] = c
end
for _, c in ipairs(ratchet("elites", "elites", ELITE_SPEC, KNOWN_ELITE_GAPS, "KNOWN_ELITE_GAPS")) do
    cases[#cases + 1] = c
end

local creatureCases = {
    { name = "the benchmark passes its own spec: both of Gluttony's floors", fn = function()
        local found = 0
        for _, f in ipairs(walk()) do
            if f.key == "gluttony/1" or f.key == "gluttony/2" then
                found = found + 1
                assert(f.n >= SPEC, "the benchmark fails the spec it sets: " .. show(f))
            end
        end
        assert(found == 2, "Gluttony's two floors were not both found on the walk")
    end },

    { name = "an egg is not a creature", fn = function()
        assert(not isCreature("character_dragon_egg"), "a Dragon Egg is an object")
        assert(not isCreature("character_scarab_egg"), "and so is a Scarab Egg")
        assert(isCreature("character_gilded_scarab"), "what hatches out of one is a creature")
    end },

    { name = "every floor fields Gluttony's variety of creatures, or is on the known-gap list", fn = function()
        local bad = {}
        for _, f in ipairs(walk()) do
            if f.n < SPEC and not KNOWN_GAPS[f.key] then
                bad[#bad + 1] = show(f) .. " -- below spec and not a known gap"
            end
        end
        assert(#bad == 0, "floors fielding fewer than " .. SPEC .. " distinct creatures:\n  "
            .. table.concat(bad, "\n  "))
    end },

    { name = "a known gap that has closed comes off the list", fn = function()
        local keys, closed = {}, {}
        for _, f in ipairs(walk()) do
            keys[f.key] = true
            if KNOWN_GAPS[f.key] and f.n >= SPEC then
                closed[#closed + 1] = show(f) .. " -- now within spec; take its line off KNOWN_GAPS"
            end
        end
        for key in pairs(KNOWN_GAPS) do
            assert(keys[key], "KNOWN_GAPS names " .. key .. ", which no floor of the rift is")
        end
        assert(#closed == 0, table.concat(closed, "\n  "))
    end },
}
for _, c in ipairs(cases) do creatureCases[#creatureCases + 1] = c end
return creatureCases
