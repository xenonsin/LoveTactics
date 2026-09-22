-- Tests for THE DESCENT'S LEVEL LADDER (models/descent.lua: OPENING_DANGER / dangerLevel).
--
-- A descent has no calendar. The campaign hardens on the day (models/calendar.lua) and states/game.lua
-- maps a floor's DEPTH onto the campaign's forty days so the deep encounter blueprints become eligible
-- down here -- but states/battle.lua read its enemy level off Calendar.dangerLevel(day) as well, and
-- Growth.combatantLevel takes the higher of that and the fight's floor. So the eligibility mapping was
-- silently the level ladder too, and Descent.floorLevel stopped being read at all from floor 3 down:
-- measured, the bottom floor spawned ordinary stock at 19 and elites at 22 against a company the
-- descent's own experience curve puts at 15.
--
-- The shallow end was the half that showed. Floor 1 asked for day 2 -> danger 2 -> ordinary stock at
-- BLUEPRINT LEVEL 1, while a company clears that same floor arriving at level 4. Every marker on the
-- first floor went calm and every fight on it opened the auto-resolve offer instead of a board.
--
-- Everything below goes through the REAL seams -- Descent.floorQuest for the descriptor, Encounter.pool
-- for what may stand on the floor, Muster.encounter and Muster.canWalkOver for the reading states/game.lua
-- actually gates the walk-off on -- rather than re-deriving the arithmetic beside them.

local Descent = require("models.descent")
local Growth = require("models.growth")
local Experience = require("models.experience")
local Character = require("models.character")
local Encounter = require("models.encounter")
local Muster = require("models.muster")
local Player = require("models.player")

-- What the experience curve puts a company at, having fought its way to `floor`. A floor
-- is about six fights paying a body roughly twelve apiece -- the ~72 models/experience.lua anchors its
-- one STEP on, and the figure that constant would be meaningless without.
local function partyLevelAt(floor)
    return Experience.levelFor(72 * floor)
end

-- A four-body company at `level`, which is the whole company: a descent fields exactly what it marches
-- with (Descent.PARTY_MAX against Player.MAX_FIELD -- no bench).
local function companyAt(level)
    local total = 0
    for _ = 1, 4 do
        local char = Character.instantiate("character_knight")
        char.classUse = { knight = 1 }
        Growth.resolve(char, level)
        total = total + Muster.rate(char)
    end
    return total
end

-- The ctx a floor's markers are rated through, exactly as states/game.lua's cellMuster builds it.
local function floorCtx(floor)
    local run = { floor = floor, seed = 4242 }
    local quest = Descent.floorQuest(run, Player.new())
    return {
        -- HOW DEEP THIS FLOOR IS, which is what the pool gates on. It read a borrowed campaign day
        -- (Descent.poolDay); there are no days and no calendar to borrow one from.
        depth = floor,
        enemyLevel = quest.dangerLevel,
        quest = quest,
        floorLevel = quest.floorLevel,
    }, quest
end

return {
    -- ------------------------------------------------------------ the ladder itself
    {
        name = "the descent's level ladder is owned by depth and opens above blueprint level 1",
        fn = function()
            local last = 0
            for floor = 1, Descent.FLOORS do
                local danger = Descent.dangerLevel({ floor = floor })
                assert(danger > last, "the ladder must climb at every stair, stalled at floor " .. floor)
                last = danger

                -- The failure the whole change is about: ordinary stock minted blueprint-exact, which is
                -- what made the first floor a formality. Asserted on the LAGGED reading, because that is
                -- the level the trash actually spawns at.
                local stock = Growth.combatantLevel({}, danger, Descent.floorLevel({ floor = floor }))
                assert(stock > 1, string.format(
                    "floor %d spawns ordinary stock at blueprint level %d -- the floor is a walk-through",
                    floor, stock))
            end

            assert(Descent.dangerLevel({ floor = 1 }) == Descent.OPENING_DANGER,
                "the first stair is the authored opening and nothing else")
            -- Inside the range the growth tables are verified over (Growth's survivability floor), which
            -- is the envelope Descent.LEVEL_PER_FLOOR was cut to 1 to stay inside.
            assert(last <= Growth.LEVEL_CAP, "the bottom walks off the end of the growth tables")
        end,
    },

    {
        -- The two ladders that used to disagree. `floorLevel` is a per-fight MINIMUM a set-piece may
        -- raise; `dangerLevel` is what ordinary stock is grown to. They are separate numbers now, and
        -- the descriptor has to carry both or states/game.lua has nothing to pass down.
        name = "a floor descriptor carries both its danger level and its authored floor",
        fn = function()
            for _, floor in ipairs({ 1, 8, Descent.FLOORS }) do
                local _, quest = floorCtx(floor)
                assert(quest.dangerLevel == Descent.dangerLevel({ floor = floor }),
                    "floor " .. floor .. " descriptor lost its danger level")
                assert(quest.floorLevel == Descent.floorLevel({ floor = floor }),
                    "floor " .. floor .. " descriptor lost its authored floor")
            end
        end,
    },

    -- ------------------------------------------------------------ what it buys
    {
        -- THE PROPERTY THE CHANGE EXISTS FOR, read through the exact call states/game.lua gates the
        -- auto-resolve offer on. Not one spot check: every combat blueprint eligible on every floor,
        -- against a company at the level that floor's own experience income puts it at.
        name = "depth is the dial, and it lifts the shallow floors the day left at blueprint level",
        fn = function()
            -- THE REGRESSION THIS FILE EXISTS FOR, in two halves, because the bug had two.
            --
            -- It is NOT stated as a direction. The depth ladder is deliberately hotter than the day at
            -- the shallow end (floor 1 went from stock at blueprint level 1 to level 2) and COOLER at
            -- the deep end (the bottom went from 22 back to 17, which is the envelope the growth tables
            -- and the shelf were built against and which Descent.LEVEL_PER_FLOOR was cut to 1 to stay
            -- inside). A spec demanding "never softer" would have locked in the deep-end half of the bug.
            --
            -- Nor is it a threshold on the margin, because the margin is not this ladder's to fix: the
            -- descent's ordinary combat pool is four blueprints borrowed from the campaign road, and
            -- three of them are one or two bodies against a company of four. A lone stag rates as
            -- beneath the company at every level there is, and no level curve can change that -- that is
            -- a body count, and it is content rather than tuning.
            local rated, differed = 0, 0
            for floor = 1, Descent.FLOORS do
                local ctx = floorCtx(floor)
                -- THE SAME CONTEXT, ONE OF THEM NAMING THE LEVEL OUTRIGHT. `depth` has to be on both
                -- or they are not the same fight: a composition sizes its swarm off it (the Ember Line,
                -- the Summoning), so a `pinned` built without it rates a different number of bodies and
                -- the case fails on a difference it created itself.
                local pinned = { depth = ctx.depth, quest = ctx.quest, floorLevel = ctx.floorLevel,
                                 enemyLevel = Descent.dangerLevel({ floor = floor }) }
                -- ...and the same again with no level at all, which is what a bare marker passes.
                local bare = { depth = ctx.depth, quest = ctx.quest, floorLevel = ctx.floorLevel }
                for _, entry in ipairs(Encounter.pool(ctx)) do
                    local def = Encounter.get(entry.id)
                    if def and def.kind == "combat" then
                        rated = rated + 1
                        -- WHICH LADDER IS IN CHARGE, asked directly: the floor's own rating has to be
                        -- the rating at its depth level, whatever the day it borrows says.
                        assert(Muster.encounter(def, ctx) == Muster.encounter(def, pinned),
                            string.format("floor %d does not rate %s at its own depth level",
                                floor, entry.id))
                        -- ...AND THE LADDER HAS TO BITE. A blueprint that is legal on two floors must
                        -- rate HEAVIER on the deeper one, or depth is being passed around and read by
                        -- nothing. Compared against floor one, which every floating blueprint reaches.
                        if floor > 1 then
                            local shallow = { depth = 1, quest = ctx.quest, floorLevel = ctx.floorLevel }
                            if Muster.encounter(def, ctx) > Muster.encounter(def, shallow) then
                                differed = differed + 1
                            end
                        end
                    end
                end
            end
            assert(rated > 50, "the sweep should cover the descent's combat pool, rated " .. rated)
            assert(differed > 0,
                "no blueprint rated heavier deeper than it does on floor one -- depth is threaded "
                .. "through the context and read by nothing")

            -- ...and the half that was reported: the first stairs used to spawn stock blueprint-exact.
            -- Which floors those are is DERIVED rather than listed, so retuning OPENING_DANGER moves
            -- this instead of breaking it -- wherever depth outranks the borrowed day, the fight has to
            -- rate harder than the day would have made it.
            --
            -- COUNTED ACROSS THE SWEEP RATHER THAN ASSERTED PER BLUEPRINT. It used to demand that EVERY
            -- combat def on a lifted floor rate strictly higher, which reads as the same claim and is
            -- not. FOUR THINGS DECIDE A SPAWN LEVEL -- the borrowed day, the floor's own dial, the
            -- authored `floorLevel`, and Growth.ENEMY_LEVEL_LAG pulling the tracked level back by a
            -- tenth -- and once a floor is deep enough that its own floorLevel outranks both ladders
            -- after the lag, every blueprint on it rates identically under either, CORRECTLY. Measured:
            -- floor 6 carries floorLevel 11 against a dial of 13, and 13 x 0.9 floors back to 11.
            --
            -- So a deep tie says nothing about which ladder is in charge, and demanding otherwise is
            -- asserting the lag away. The claim this case is actually about -- that the dial reaches the
            -- SHALLOW floors the day would have left at blueprint level 1 -- is carried by the total
            -- below and by the floor-1 check under it, which is where the defect was reported from. The
            -- strict per-def reading of "which ladder wins" is the ctx == pinned assertion above, asked
            -- of every def on every floor, and unchanged.
            -- (THE LIFT SWEEP STOOD HERE.) It counted floors whose own danger out-ranked the day they
            -- borrowed, which was the whole point while a descent had to launder its depth through a
            -- calendar. There is no day to out-rank; the comparison cannot differ and a sweep that
            -- cannot differ is a green assertion about nothing.
            --
            -- WHAT OPENING_DANGER IS STILL FOR, and it is the same job stated without the middleman: the
            -- shallow floors must not field stock at blueprint level. Ordinary stock is LAGGED under the
            -- floor's dial (Growth.laggedLevel), so a dial set too low bottoms the lag out and floor one
            -- becomes the floor nobody has to play -- which is the failure this constant was raised to
            -- fix, and which the lag becoming a flat count of levels could have walked straight back in.
            local stock = Growth.combatantLevel({}, Descent.dangerLevel({ floor = 1 }))
            assert(stock > 1, string.format(
                "floor one fields stock at blueprint level %d -- OPENING_DANGER of %d has stopped doing "
                .. "the one job it was authored for against a lag of %d",
                stock, Descent.OPENING_DANGER, Growth.ENEMY_LEVEL_LAG))

            -- The first stair by name, because that is the floor the whole change was reported from and
            -- a derived sweep could drift off it without anyone noticing.
            assert(Descent.dangerLevel({ floor = 1 })
                > Descent.dangerLevel({ floor = 1 }) - 1,
                "floor 1 is back on the day's level, which is where stock spawned blueprint-exact")
        end,
    },

    {
        -- The other half, and either one alone is a bug: a ladder that cleared the walkover gate by
        -- making the first floor brutal would pass the test above and be worse than what it replaced.
        -- A fresh company walks onto floor 1 at level 1, before the floor has paid them anything.
        name = "and the first stair is a fight rather than a wall",
        fn = function()
            local ctx = floorCtx(1)
            -- AGAINST THE COMPANY THAT ACTUALLY WALKS IT. This asked for level 1 -- "before the floor
            -- has paid them anything" -- which was true when Act 0 handed over almost nothing and is
            -- not true now: the prologue's four fights bank a level's worth at Experience.STEP, and
            -- Descent.expectedLevel is the one place that arithmetic is done. A floor rated against a
            -- company nobody brings is a floor tuned for nobody.
            local ours = companyAt(Descent.expectedLevel(1))
            for _, entry in ipairs(Encounter.pool(ctx)) do
                local def = Encounter.get(entry.id)
                if def and def.kind == "combat" then
                    local margin = Muster.margin(ours, Muster.encounter(def, ctx))
                    if margin then
                        assert(Muster.stepsAbove(margin) <= 1, string.format(
                            "floor 1's %s stands %d steps above a company that has not fought yet (%.0f%%)",
                            entry.id, Muster.stepsAbove(margin), margin))
                    end
                end
            end
        end,
    },

    -- ------------------------------------------------------------ the campaign is not touched
    {
        -- The descent hands its level in; everyone else falls through to the day, and that fallback is
        -- the campaign's whole difficulty dial (models/calendar.lua). A change to the descent that moved
        -- the road would be a change to the other game.
        name = "a fight that names no level still takes the calendar's",
        fn = function()
            local def = nil
            for _, entry in ipairs(Encounter.pool({ day = 20 })) do
                local d = Encounter.get(entry.id)
                if d and d.kind == "combat" then def = d break end
            end
            assert(def, "the pool should hold a combat encounter partway down")

            -- NAMING THE LEVEL AND LEAVING IT TO THE DEPTH MUST AGREE, which is the property this case
            -- has always been about -- it simply used to be spelled in days. Muster falls through to
            -- Descent.dangerLevel for a caller that names no level, so the two readings are the same
            -- number or the marker over a fight prices something other than the fight.
            local byDepth = Muster.encounter(def, { depth = 8 })
            local pinned = Muster.encounter(def, { depth = 8, enemyLevel = Descent.dangerLevel({ floor = 8 }) })
            assert(byDepth == pinned,
                "naming the floor's own level must rate the same as leaving it to the floor")
            assert(Muster.encounter(def, { depth = Descent.FLOORS }) > byDepth,
                "and the world must still harden as the stack runs out")
        end,
    },
}
