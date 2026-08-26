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
local Calendar = require("models.calendar")

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
        day = math.max(1, math.floor(floor / Descent.FLOORS * Calendar.SPAN)),
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
                local byDay = { day = ctx.day, quest = ctx.quest, floorLevel = ctx.floorLevel }
                local pinned = { day = ctx.day, quest = ctx.quest, floorLevel = ctx.floorLevel,
                                 enemyLevel = Descent.dangerLevel({ floor = floor }) }
                for _, entry in ipairs(Encounter.pool(ctx)) do
                    local def = Encounter.get(entry.id)
                    if def and def.kind == "combat" then
                        rated = rated + 1
                        -- WHICH LADDER IS IN CHARGE, asked directly: the floor's own rating has to be
                        -- the rating at its depth level, whatever the day it borrows says.
                        assert(Muster.encounter(def, ctx) == Muster.encounter(def, pinned),
                            string.format("floor %d does not rate %s at its own depth level",
                                floor, entry.id))
                        if Muster.encounter(def, ctx) ~= Muster.encounter(def, byDay) then
                            differed = differed + 1
                        end
                    end
                end
            end
            assert(rated > 50, "the sweep should cover the descent's combat pool, rated " .. rated)
            assert(differed > 0,
                "the depth ladder never differed from the day anywhere -- it is not wired in")

            -- ...and the half that was reported: the first stairs used to spawn stock blueprint-exact.
            -- Which floors those are is DERIVED rather than listed, so retuning OPENING_DANGER moves
            -- this instead of breaking it -- wherever depth outranks the borrowed day, the fight has to
            -- rate harder than the day would have made it.
            local lifted = 0
            for floor = 1, Descent.FLOORS do
                local ctx = floorCtx(floor)
                if Descent.dangerLevel({ floor = floor }) > Calendar.dangerLevel(ctx.day) then
                    local byDay = { day = ctx.day, quest = ctx.quest, floorLevel = ctx.floorLevel }
                    for _, entry in ipairs(Encounter.pool(ctx)) do
                        local def = Encounter.get(entry.id)
                        if def and def.kind == "combat" then
                            assert(Muster.encounter(def, ctx) > Muster.encounter(def, byDay),
                                string.format("floor %d still rates %s at the day's level -- the shallow "
                                    .. "floors are back to spawning stock the company walked past",
                                    floor, entry.id))
                            lifted = lifted + 1
                        end
                    end
                end
            end
            assert(lifted > 0, string.format(
                "no floor is lifted above the day it borrows -- OPENING_DANGER of %d has stopped doing "
                .. "the one job it was authored for", Descent.OPENING_DANGER))

            -- The first stair by name, because that is the floor the whole change was reported from and
            -- a derived sweep could drift off it without anyone noticing.
            assert(Descent.dangerLevel({ floor = 1 })
                > Calendar.dangerLevel(math.max(1, math.floor(Calendar.SPAN / Descent.FLOORS))),
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
            local ours = companyAt(1)
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
            assert(def, "the campaign pool should hold a combat encounter at day 20")

            local byDay = Muster.encounter(def, { day = 20 })
            local pinned = Muster.encounter(def, { day = 20, enemyLevel = Calendar.dangerLevel(20) })
            assert(byDay == pinned,
                "naming the day's own level must be the same rating as leaving it to the day")
            assert(Muster.encounter(def, { day = 40 }) > byDay,
                "and the campaign must still harden as the calendar runs out")
        end,
    },
}
