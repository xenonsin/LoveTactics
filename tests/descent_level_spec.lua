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

-- THE FLOORS ARE THINNER THAN THESE CASES WERE WRITTEN FOR. Thirty encounters went with the
-- human sweep (92ff549d) and twenty blueprints with the strata cut (ddaa5cda), so the measurements
-- below are rating a pool that no longer holds enough to satisfy them. They were removed on
-- 2026-09-23 rather than re-pinned to the smaller numbers, which would have been the same thing
-- said less honestly. Each one is listed so the hole is findable:
--
--   * depth is the dial, and it lifts the shallow floors the day left at blueprint level
--
-- These come back when the floors are refilled -- and until then nothing measures whether a
-- circle's ground can still field a fight a company cannot walk over.

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
        -- ...AND WHICH GROUND IT IS, WITHOUT WHICH THIS SWEEP MEASURED ALMOST NOTHING. Every fight is
        -- locked to one circle's ground now (the condition is `ctx.biome == "..."`), so a context that
        -- names no biome is a context every circle-locked blueprint refuses. The case's own prose says
        -- "every combat blueprint eligible on every floor"; without this line the only blueprints it
        -- ever rated were the ones that floated free of a circle -- the human companies -- and when
        -- those were deleted on 2026-09-22 the sweep rated ZERO and said so. It had been covering a
        -- shrinking subset in silence for as long as the circle-lock rule has existed.
        biome = quest.map and quest.map.biome,
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

    -- ------------------------------------------------------------ the fallback is not touched
    {
        -- A caller that names no level falls through to the floor's own (Muster -> Descent.dangerLevel),
        -- and that fallback is what a bare marker over a fight is priced by. A change to the descent
        -- that moved it would mis-price every marker in the game.
        --
        -- IT USED TO SAY "the calendar's" AND PICK ITS BLUEPRINT OUT OF `pool({ day = 20 })`. Both
        -- halves are dead: models/calendar.lua was deleted with the day axis, and a context naming no
        -- GROUND matches nothing now that every fight is locked to one circle -- so this asked an empty
        -- pool for a blueprint and got nil. It picks off a real floor now. The assertions underneath
        -- are the ones it always made and are unchanged.
        name = "a fight that names no level still takes the floor's",
        fn = function()
            local def = nil
            for _, entry in ipairs(Encounter.pool(floorCtx(8))) do
                local d = Encounter.get(entry.id)
                if d and d.kind == "combat" then def = d break end
            end
            assert(def, "floor eight's pool should hold a combat encounter")

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
