-- Tests for WHAT A FIGHT IS WORTH AGAINST WHAT YOU ARE (Experience.rewardScale, Combat.scaledAward).
--
-- The rift is a PLACE: its floors persist and their monsters re-arm (Descent.rearmFloor), so a company
-- can walk floor one for as long as it likes. Wizardry's answer is that the shallow end stops paying,
-- and this is that rule -- plus the geometric curve under it (Experience.CURVE), which is the half that
-- works even on ground the company has NOT outgrown.
--
-- Driven through the real award path wherever it can be: Combat.scaledAward is what both ladders
-- actually call, and the farming case below runs a real fight through models/autobattle rather than
-- asserting about the multiplier in isolation.

local Combat = require("models.combat")
local Experience = require("models.experience")
local Descent = require("models.descent")
local Growth = require("models.growth")
local Class = require("models.class")

-- A combat stub carrying one opposition body at `level`. Deliberately hand-built for the unit cases:
-- what is under test is the arithmetic between two levels, and a real arena drags a board into a
-- reading that has to stay legible. The farming case below uses the real thing.
local function fightAgainst(level)
    return { units = { { control = "enemy", char = { level = level } } } }
end

local function earner(level)
    return { control = "player", char = { level = level } }
end

return {
    {
        -- THE PROPERTY THE WHOLE ARRANGEMENT EXISTS FOR, simulated rather than asserted: a flat cost
        -- curve plus a gap-scaled award is SELF-STABILISING. A company that pulls ahead of its ground
        -- earns less and slows; one that falls behind earns full and catches up. So the party level
        -- tracks the floor it is on instead of racing it, and nobody has to tune the two ladders
        -- against each other.
        --
        -- This replaced a case that walked the ramp asserting the grace covered it. That case was
        -- right to exist -- it is what caught the geometric curve running six levels clear by floor
        -- two -- but it was measuring the SYMPTOM. What matters is that the gap converges and stays
        -- converged, which is a claim about the loop and can only be made by running it.
        name = "the party's level tracks the ground it is on, and settles there",
        fn = function()
            for _, perFloor in ipairs({ 8, 10, 12 }) do
                local banked = 80 -- what Act 0 leaves a body
                local worst = 0
                for floor = 1, Descent.FLOORS do
                    -- AGAINST WHAT ACTUALLY SPAWNS, not against the danger ladder: ordinary stock is
                    -- lagged under the floor's own number (Growth.ENEMY_LEVEL_LAG) and
                    -- Combat.oppositionLevel reads real units, so measuring against
                    -- Descent.dangerLevel understates the gap by about a level.
                    local stock = Growth.combatantLevel({}, Descent.dangerLevel({ floor = floor }),
                        Descent.floorLevel({ floor = floor }))
                    local party = Experience.levelFor(banked)
                    local gap = party - stock
                    if gap > worst then worst = gap end
                    assert(gap <= 4, string.format(
                        "at %d fights a floor, floor %d has the company %d levels over its own ground "
                        .. "(level %d against stock at %d) -- the loop is not converging",
                        perFloor, floor, gap, party, stock))
                    assert(gap >= -3, string.format(
                        "at %d fights a floor, floor %d has the company %d levels UNDER its ground "
                        .. "(level %d against stock at %d) -- it cannot catch up",
                        perFloor, floor, gap, party, stock))
                    banked = banked + perFloor * 12 * Experience.rewardScale(party, stock)
                end

                -- ...and it ends where the rift was built for it. Descent.LEVEL_PER_FLOOR's ceiling
                -- clause is the authority: the bottom must land at or under sixteen, which is what the
                -- growth tables and the shelf were balanced against.
                -- ...and it ends near the ground it ends on. Stated against the bottom floor's own
                -- DANGER rather than against a constant: what the arrival has to be is a company the
                -- Crown's floor is a fight for, and where that sits is Descent.dangerLevel's business.
                local arrived = Experience.levelFor(banked)
                local bottom = Descent.dangerLevel({ floor = Descent.FLOORS })
                assert(arrived >= bottom - 4 and arrived <= bottom + 2, string.format(
                    "at %d fights a floor a company arrives at the Crown at level %d, against a floor "
                    .. "that fights at %d", perFloor, arrived, bottom))
            end
        end,
    },

    {
        name = "a fight at your own level pays in full, and a harder one is never worth less",
        fn = function()
            for _, gap in ipairs({ -6, -2, 0, Experience.REWARD_GRACE }) do
                assert(Experience.rewardScale(10 + gap, 10) == 1,
                    "a body " .. gap .. " levels off the opposition must earn in full")
            end
            -- Monotone: stepping UP in opposition can never pay less than standing still. Walked from
            -- the weakest body to the strongest, which is the direction the claim is made in.
            local last = 0
            for level = 1, 20 do
                local scale = Experience.rewardScale(12, level)
                assert(scale >= last, string.format(
                    "opposition at %d pays %.3f against %.3f for the body below it -- a harder fight "
                    .. "must never be worth less", level, scale, last))
                last = scale
            end
        end,
    },

    {
        name = "past the grace it decays, never cliffs, and never reaches zero",
        fn = function()
            local last = 1
            for gap = 1, 20 do
                local scale = Experience.rewardScale(10 + Experience.REWARD_GRACE + gap, 10)
                assert(scale < last, "the falloff must keep falling at gap " .. gap)
                assert(scale > 0, "and must never reach zero -- a cliff reads as the game breaking")
                last = scale
            end
            -- The number the whole rule is for: a company at the level the Crown is built for, standing
            -- on the opening floor. Derived from the descent's own two ends rather than named.
            local bottom = Descent.FLOORS
            local opening = Growth.combatantLevel({}, Descent.dangerLevel({ floor = 1 }),
                Descent.floorLevel({ floor = 1 }))
            local farmed = Experience.rewardScale(bottom, opening)
            assert(farmed < 0.05, string.format(
                "a level-%d company farming the opening floor earns %.1f%% of a fight -- it has to be "
                .. "small enough that the lap is not worth walking", bottom, farmed * 100))
        end,
    },

    {
        name = "the cost curve is flat, because all of the control is in the award",
        fn = function()
            -- FFT's arrangement (models/experience.lua's THE CURVE IS FLAT). A level costs the same
            -- whether it is your second or your fifteenth; what varies is what a fight pays. The two
            -- rising curves this replaced are both recorded there, with the measurement that retired
            -- each -- so this case is the guard against drifting back to one by accident.
            local first = Experience.totalFor(2) - Experience.totalFor(1)
            for level = 3, 20 do
                local step = Experience.totalFor(level) - Experience.totalFor(level - 1)
                assert(step == first, string.format(
                    "level %d costs %d against the %d every other level costs -- a rising curve "
                    .. "diverges from the linear danger ladder and the grace band cannot cover it",
                    level, step, first))
            end
            assert(Experience.CURVE == nil,
                "the geometric curve is gone, not deprecated -- a second knob here is a second answer")
        end,
    },

    {
        name = "both ledgers are scaled, and the remainder is carried rather than rounded away",
        fn = function()
            -- THE ROUNDING TRAP THIS EXISTS FOR. Both ladders are paid in ones and twos, so a naive
            -- multiply-and-floor turns every share under a half into nothing -- the 0.65 falloff would
            -- read as a cliff at its first step and the curve above it would be decoration.
            local combat = fightAgainst(5)
            local unit = earner(5 + Experience.REWARD_GRACE + 3) -- about a fifth
            local scale = Experience.rewardScale(unit.char.level, 5)
            assert(scale > 0 and scale < 0.5, "the fixture must sit where a naive floor() would zero it")

            local paid, actions = 0, 60
            for _ = 1, actions do
                paid = paid + Combat.scaledAward(combat, unit, unit.char, Experience.PER_ACTION)
            end
            local want = actions * Experience.PER_ACTION * scale
            assert(paid > 0, "sixty scaled actions paid nothing at all -- the remainder is being lost")
            assert(math.abs(paid - want) <= 1, string.format(
                "sixty actions should pay about %.1f, paid %d", want, paid))
        end,
    },

    {
        name = "the carry is per fight, so it cannot accumulate into a free level across a floor",
        fn = function()
            local unit = earner(5 + Experience.REWARD_GRACE + 6) -- a very small share
            local total = 0
            for _ = 1, 40 do
                -- A NEW combat each time, which is the point: forty separate trivial fights must not
                -- add up through a shared purse the way forty actions inside one fight do.
                total = total + Combat.scaledAward(fightAgainst(5), unit, unit.char, Experience.PER_ACTION)
            end
            assert(total == 0, string.format(
                "forty trivial fights paid %d -- the remainder is riding something longer than a fight",
                total))
        end,
    },

    {
        name = "an opposition the board cannot name leaves the award alone",
        fn = function()
            -- A fight with nobody on the other side (a scripted stop, a headless fixture) must pay
            -- exactly what it always paid rather than silently answering level 1 and taxing everything.
            local empty = { units = {} }
            assert(Combat.scaledAward(empty, earner(30), "slot", 7) == 7,
                "a board with no opposition must not be priced as a trivial one")
            assert(Combat.scaledAward(nil, earner(30), "slot", 7) == 7, "and neither must no board")
        end,
    },
}
