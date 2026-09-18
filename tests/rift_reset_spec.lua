-- Tests for THE RIFT CLOSING BEHIND THE COMPANY: the extraction rule, and the symmetry that keeps it
-- honest.
--
-- THE RULE. Leaving banks everything and throws the DUNGEON away -- new stack, new shuffle, new boards,
-- from floor one. It is what makes the way up a decision rather than a stroll back onto ground already
-- cleared: walking out costs a mark on the tally.
--
-- BOTH EXITS RESET, and the symmetry is the load-bearing half. If dying preserved the floor stack and
-- leaving did not, a company standing deep with a thin haul would be better off letting itself be
-- killed -- the mode would have built an incentive to throw fights. That claim lives in the source scan
-- at the bottom, because neither exit can be driven headlessly.
--
-- AND THE PILE IS GONE. Five cases here guarded it: a closing rift carried its heaps out onto the
-- company, idempotently, and a later dive picked them up at the depth they were lost at. That whole
-- apparatus is deleted with the wipe penalty that made it (models/descent.lua) -- a wipe takes nothing,
-- so there is nothing to strand. What replaced the pile as the cost of losing is two marks on the count
-- against the stair's one, which is asserted in tests/gate_spec where the branch itself is scanned.

local Descent = require("models.descent")
local Player = require("models.player")
local Save = require("models.save")

local function source(path)
    local f = assert(io.open(path, "r"), "cannot read " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

return {

    { name = "both exits close the rift, and that symmetry is not an accident", fn = function()
        -- SOURCE-SCANNED, because neither exit can be driven headlessly and the defect this guards
        -- against is an ASYMMETRY: one exit keeping the floor stack while the other throws it away is an
        -- incentive to throw fights, and it would read as perfectly reasonable code on either side.
        local src = source("states/game.lua")

        local up = src:find("Descent.markClimbedOut(", 1, true)
        assert(up, "nothing takes the ascent stair any more -- retarget this case")
        -- The window is a heuristic and it has to be sized against the BLOCK rather than against a
        -- round number: the climb-out branch is mostly commentary (the whole extraction argument lives
        -- in it), so a window tight enough to feel precise goes red the next time somebody writes a
        -- paragraph there rather than the next time somebody deletes a line. Widened from 3000 when the
        -- economy split added the scrip burn to this branch (models/scrip.lua).
        local upTail = src:sub(up, up + 5000)
        -- What the stair costs, which is NOTHING -- the tally is parked (Descent.COUNT_PARKED), so
        -- Descent.climbOut is called for its bookkeeping and charges no mark. The call still has to be
        -- here: it is what marks the company as having ever surfaced, which several readouts gate on.
        -- The pile assertion that stood here went with the pile.
        assert(upTail:find("Descent.climbOut(", 1, true),
            "climbing out charges nothing on the tally, so the way up is free and shuttling is untaxed")
        -- AND THE MAP GOES IN THE BOOK ON THE WAY OUT (Descent.keepFloor). Without this the one floor a
        -- company never keeps is the one it climbed out of, which is the commonest exit in the game.
        assert(upTail:find("Descent.keepFloor(", 1, true),
            "climbing out must bank the floor the company is standing on, or the map book has a hole "
            .. "exactly where the player stopped")
        assert(upTail:find("descentRun = nil", 1, true),
            "climbing out leaves the expedition open, so the next dive resumes a rift already left")

        local down = src:find("wiped = floor", 1, true)
        assert(down, "nothing sends a wiped company to the Gate any more -- retarget this case")
        -- WIDENED FROM 4000 for the reason the note above gives about the other window: this branch
        -- grew a paragraph and a Descent.keepFloor block when the map book moved onto the player, and a
        -- heuristic window sized to yesterday's block goes red on commentary rather than on a deletion.
        local downHead = src:sub(math.max(1, down - 6000), down)
        assert(downHead:find("Descent.COUNT_WIPE", 1, true),
            "a wipe still names its mark, inert though the tally is (Descent.COUNT_PARKED) -- a park "
            .. "whose call sites were deleted too is one nobody can lift from the flag alone")
        assert(downHead:find("Descent.keepFloor(", 1, true),
            "a rout must bank the floor as well: the ground a company drew before it was killed is not "
            .. "a thing it was carrying, and taking it back is a price on losing")
        assert(downHead:find("descentRun = nil", 1, true),
            "a wipe leaves the expedition open, so the next dive resumes a dead one")
    end },

    { name = "nothing sends a run to the Gate any more", fn = function()
        -- The screen used to be handed the expedition the company had just left, which is how it knew
        -- what floor to offer next. There is no such thing now: it opens a fresh one. A caller still
        -- passing `run` would be handing over a rift that has been closed.
        local src = source("states/game.lua")
        assert(not src:find("run = game.descent,", 1, true),
            "a state switch still carries the closed run to the Gate")
    end },
}
