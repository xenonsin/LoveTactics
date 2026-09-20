-- The way out of a fight that found you (models/flee.lua), and what a failed attempt costs on the
-- board (Combat.dressSide).

local Flee = require("models.flee")
local Muster = require("models.muster")
local Combat = require("models.combat")
local Status = require("models.status")

return {
    {
        name = "an end may not be fled, and everything that finds you may",
        fn = function()
            -- WHAT THE COMPANY IS CORNERED BY. A rolled fight arrives with no marker to read, and a
            -- seated elite can be misjudged from across the board -- both are positions this exists for.
            assert(Flee.allowed({ kind = "combat" }), "a rolled fight cannot be escaped")
            assert(Flee.allowed({ kind = "elite" }), "a standing elite cannot be escaped")

            -- AN END IS THE WORK THE PLAYER CAME DOWN FOR, reached by choosing to walk onto a marker
            -- that has been visible since the fog lifted. There is nothing to escape: they arrived.
            assert(not Flee.allowed({ kind = "objective" }),
                "the stair's own general offers a Run Away plate, which is a button labelled 'undo'")
            -- ...and nothing that is not a fight at all.
            assert(not Flee.allowed({ kind = "merchant" }), "a shop offered an escape")
            assert(not Flee.allowed({ kind = "rest" }), "a camp offered an escape")
            assert(not Flee.allowed(nil), "a cell with nothing on it offered an escape")
        end,
    },
    {
        name = "the plate always works, at every margin and with no reading at all",
        fn = function()
            -- THE BAND HAS TO BE ACTIONABLE. The deploy screen stands the enemy line on the real board
            -- with the muster reading behind it, whose whole job is to say "this is above you" in time
            -- to matter; a plate that then refused four times in five would make that reading advisory,
            -- which is the one thing a readout in this game may never be (models/flee.lua's header).
            assert(Flee.CERTAIN, "the escape is no longer certain -- this case pins the live rule")

            for _, margin in ipairs({ 0, 1, 25, 40, 60, 100, 150, 200, 400, 10000 }) do
                assert(Flee.chance(margin) == 100, string.format(
                    "a margin of %d quotes %d%%, not certainty", margin, Flee.chance(margin)))
            end

            -- A fight with no reading at all (an empty or unresolvable composition) is escapable on the
            -- same terms. There is nothing to compare, and there is nothing left to compare it FOR.
            assert(Flee.chance(nil) == 100, "an unreadable fight cannot be fled at all")

            -- AND THE NUMBER REACHES THE ROLL. Flee.roll was never faked into always answering true --
            -- it honours the chance it is handed, and what changed is the chance.
            for leg = 0, 20 do
                assert(Flee.roll(77, leg, Flee.chance(100)),
                    "a certain break-away failed at leg " .. leg)
            end
        end,
    },
    {
        name = "the parked curve still derives, so the revert is one flag",
        fn = function()
            -- PARKED, NOT DELETED (Flee.CERTAIN). A retired rule that nobody exercises is a rule that
            -- rots quietly and has to be re-derived the day it is wanted back, so this case flips the
            -- flag and holds the old curve to the argument it was authored with.
            local was = Flee.CERTAIN
            Flee.CERTAIN = false
            local ok, err = pcall(function()
                -- The odds ran the WRONG WAY on purpose: the fight you most wanted out of was the one
                -- you were least likely to escape. That is what retired it, and it is what the curve is.
                local outmatched = Flee.chance(40)   -- "far above you" (Muster.BANDS)
                local even = Flee.chance(100)
                local ahead = Flee.chance(Muster.WALK_OVER)

                assert(outmatched < even and even < ahead, string.format(
                    "the parked odds do not climb with the company: %d%% outmatched, %d%% even, %d%% ahead",
                    outmatched, even, ahead))
                assert(even == Flee.EVEN,
                    "an even fight reads " .. even .. "%, not the authored " .. Flee.EVEN .. "%")

                -- Never certain and never hopeless: a plate whose answer is known before it is pressed
                -- is not a decision, and a cornered party with no way out is a cutscene.
                for _, margin in ipairs({ 0, 1, 25, 60, 100, 150, 200, 400, 10000 }) do
                    local c = Flee.chance(margin)
                    assert(c >= Flee.MIN and c <= Flee.MAX, string.format(
                        "a margin of %d reads %d%%, outside the declared %d-%d",
                        margin, c, Flee.MIN, Flee.MAX))
                end

                assert(Flee.chance(nil) == Flee.EVEN, "an unreadable fight cannot be fled at all")
            end)
            -- Restored whether or not the body threw: a spec that leaves a global flag flipped takes
            -- every later case down with it, and the failure would name the wrong file.
            Flee.CERTAIN = was
            assert(ok, err)
        end,
    },
    {
        name = "the roll is off the seed, so a break-away can be replayed and not save-scummed",
        fn = function()
            -- The rule every roll in the descent keeps (models/seed.lua), and it matters more here than
            -- most: this one decides whether a fight happens at all.
            local a = Flee.roll(909, 3, 55)
            local b = Flee.roll(909, 3, 55)
            assert(a == b, "the same run, leg and odds rolled two different answers")

            -- A CERTAINTY AND AN IMPOSSIBILITY are honoured exactly, which is what lets a caller pin a
            -- spec (and what proves the comparison is not off by one at either end).
            for leg = 0, 40 do
                assert(Flee.roll(1, leg, 100), "a 100% break-away failed at leg " .. leg)
                assert(not Flee.roll(1, leg, 0), "a 0% break-away succeeded at leg " .. leg)
            end

            -- IT IS A ROLL, and over a run of legs it has to come out both ways -- a "chance" that
            -- always answered the same would be a rule wearing a percentage.
            local won, lost = 0, 0
            for leg = 0, 199 do
                if Flee.roll(4242, leg, 55) then won = won + 1 else lost = lost + 1 end
            end
            assert(won > 0 and lost > 0,
                "200 legs at 55% came back " .. won .. " away / " .. lost .. " caught -- not a roll")
            -- ...and somewhere near the number on the plate. Wide bounds: this is checking the draw is
            -- not skewed, not that a hash is a statistician.
            assert(won >= 80 and won <= 140, string.format(
                "200 legs at 55%% got away %d times, which is not the odds the button quoted", won))
        end,
    },
    {
        name = "a failed break-away dresses the ENEMY line in Hasted, and touches nothing else",
        fn = function()
            -- A tiny two-unit board, built the way the model builds one.
            local function body(name, speed)
                return { name = name, stats = { health = { current = 20, max = 20 }, speed = speed,
                         damage = 5, defense = 0 }, inventory = {} }
            end
            local combat = {
                units = {
                    { char = body("ours", 5), side = "party", initiative = 2, alive = true },
                    { char = body("theirs", 5), side = "enemy", initiative = 3, alive = true },
                },
                clock = 0,
            }
            local ours, theirs = combat.units[1], combat.units[2]

            local n = Combat.dressSide(combat, "enemy", Flee.CAUGHT_STATUS,
                { duration = Flee.CAUGHT_TICKS })
            assert(n == 1, "the catch dressed " .. n .. " bodies; it should dress the enemy's one")

            -- THE COST IS A STATUS THE PLAYER CAN SEE, which is the whole reason this replaced a shove
            -- inside the initiative countdown: the badge is on the token during the deploy phase, and
            -- the plate's own note shows the very tooltip it will carry (ui/deploy_phase.lua).
            assert(Status.has(theirs, Flee.CAUGHT_STATUS), "the enemy line is not Hasted")
            assert(not Status.has(ours, Flee.CAUGHT_STATUS),
                "the company was Hasted too, which hands the penalty back")

            -- SIDED, and only that side. A dress that caught everybody would be no penalty at all.
            assert(Combat.dressSide(combat, "party", Flee.CAUGHT_STATUS) == 1,
                "the same call does not reach the other side")

            -- IT LASTS THE OPENING, not the fight. The blueprint's own clock is a boon somebody paid
            -- for; a whole enemy line wearing four quickened turns is a different fight, not a worse one.
            assert(Status.get(theirs, Flee.CAUGHT_STATUS).remaining == Flee.CAUGHT_TICKS,
                "the caught line is not wearing the duration a catch is priced at")

            -- NOTHING ON THE CLOCK. The old failure pushed the company's initiative out past an opening
            -- action; a status carries the cost now, so the countdown is left exactly as the fight
            -- would have opened it.
            assert(ours.initiative == 2 and theirs.initiative == 3,
                "dressing a side moved the initiative countdown as well")
        end,
    },
    {
        -- The status is one the game already teaches, which is the whole reason the plate could name
        -- its stake in a single line: "enemies start combat Hasted" needed no gloss of its own.
        --
        -- PARKED (Flee.CERTAIN): no escape can fail, so nothing applies this today. Held whole anyway,
        -- because the other half of parking a rule rather than deleting it is that the rule keeps being
        -- checked -- a penalty left untested for a year is one that has to be re-derived to come back.
        name = "the parked catch is Hasted, cut to the opening",
        fn = function()
            local def = Status.defs[Flee.CAUGHT_STATUS]
            assert(def, "Flee.CAUGHT_STATUS names no status at all")
            assert(def.name == "Hasted", "the caught status is " .. tostring(def.name) .. ", not Hasted")

            -- SHORTER THAN THE BLUEPRINT, deliberately and in that direction: a catch prices the beat
            -- the company would have had to itself, not the four turns a bought Haste hands one body.
            assert(Flee.CAUGHT_TICKS > 0, "a catch that costs no time at all is not a stake")
            assert(Flee.CAUGHT_TICKS < (def.duration or 0),
                "a catch dresses the whole enemy line for as long as a paid-for Haste dresses one body")
            -- ...and long enough to still BE the opening. Below a turn it never reaches the exchange
            -- the plate is warning about.
            assert(Flee.CAUGHT_TICKS >= Status.TICKS_PER_TURN,
                "a catch of " .. Flee.CAUGHT_TICKS .. " ticks is gone before the first exchange")
        end,
    },
    {
        -- ONE NUMBER, BOTH SURFACES. The note beside the Run Away plate drew this very instance
        -- (ui/deploy_phase.lua's fleeCaughtStatus), so the hourglass read before the press was the one
        -- the badge carried after it. Two constructions would be two accounts, free to drift on the
        -- next tune -- and the readout, being the one nobody tests by playing, is the one that lies.
        --
        -- PARKED with the catch: the note shows FLEE_NOTE_CERTAIN now and stacks no status box under it.
        -- This still pins the pairing, so the revert brings back one account rather than two.
        name = "the parked note would show the status the catch lands",
        fn = function()
            local shown = Flee.caughtStatus()
            assert(shown and shown.id == Flee.CAUGHT_STATUS,
                "the readout is built from some other status than the one a catch applies")
            assert(shown.remaining == Flee.CAUGHT_TICKS,
                "the readout promises " .. tostring(shown.remaining) .. " ticks and the catch lands "
                .. Flee.CAUGHT_TICKS)
            assert(shown.def and shown.def.description,
                "the readout carries no description, so the status tooltip would open blank")
        end,
    },
    {
        name = "dressing a side nobody is on, or no board at all, is safe",
        fn = function()
            -- The host calls this from a UI callback, where the battle may already be gone.
            assert(Combat.dressSide(nil, "enemy", Flee.CAUGHT_STATUS) == 0, "dressing nothing raised")
            assert(Combat.dressSide({ units = {} }, "enemy", Flee.CAUGHT_STATUS) == 0,
                "dressing an empty board raised")
            assert(Combat.dressSide({ units = {} }, nil, Flee.CAUGHT_STATUS) == 0,
                "dressing with no side named raised")
            assert(Combat.dressSide({ units = {} }, "enemy") == 0, "dressing with no status named raised")
        end,
    },
}
