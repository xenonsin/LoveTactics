-- THE SHELF CURVE: how many wares a class's ladder deals on each of its rungs.
--
-- WHAT WAS WRONG. Nothing decided this. Two passes write `unlockLevel` -- tools/grade_report spreads a
-- class's PRICED stock across its own ladder, tools/drop_tier spread the UNPRICED half across the rift's
-- depths -- and the player meets the SUM of the two at one counter. Neither pass could see the sum, and
-- the second was not even cut per class: it ranked every find in the game together and dealt them out
-- globally, so a house's found gear landed wherever its grades happened to fall in that one ranking.
--
-- Measured at the Bastion, through Vendor.stock, the rungs opened:
--
--     5  2  5  1  3  3  9  4  3  5  7  5  7  2  6  0
--
-- A player climbing the knight ladder is handed nine wares at level six and one at level three, and the
-- top rung -- fifteen floors of committed play -- opens nothing at all. Across the seven houses FIFTEEN
-- of the 112 rungs opened nothing whatever. That is not a curve anyone chose; it is two even spreads
-- laid over each other, one of them cut on the wrong axis.
--
-- THE SHAPE IS A RAMP, SHALLOW AT THE FRONT. `M.RAMP` is the ratio between the deepest rung's intake and
-- the shallowest's, and the front is the end that matters: a company on its first morning holds a few
-- hundred gold and can act on two or three choices, so dealing it eight is dealing it a wall to read
-- rather than a decision to make. Deep rungs can carry more because by then the purse can act on more,
-- and because a catalogue that has to fit sixteen rungs has to put its bulk somewhere. Knight's 67
-- wares come out 2, 2, 3, 3 ... 6, 6 instead of the histogram above.
--
-- EVENLY WOULD NOT DO. The catalogue is 40 to 68 wares a house against sixteen rungs, so an even cut is
-- four a rung from the first morning -- barely under what the front deals today, which is the thing
-- being complained about.
--
-- THE COUNTS ARE LEFT WHERE THE ROUNDING PUT THEM, AND SORTING THEM IS THE TRAP. A cumulative round off
-- an exact ramp lands within one ware of the curve at every rung, so the ones and twos it scatters can
-- leave a rung dealing one less than the rung beneath it. Sorting the counts ascending flattens that out
-- and is wrong, measured: it moves every ZERO to the front, and a set smaller than the ladder is nearly
-- all zeros. The forty disciplines carry seven to thirteen wares over fifteen rungs, and sorted they came
-- out `0 0 0 0 0 0 0 0 0 0 1 1 1 1 1` -- a Bulwark holder opens nothing whatever until Bulwark 11, which
-- is a gate that opens nothing wearing a different hat.
--
-- Unsorted, the same nine wares span the whole ladder and simply thicken as it goes. A rung dealing one
-- fewer than the last is not a shelf going backwards: a shelf only ever grows, because what a rung deals
-- is ADDED to everything under it. Monotonic cumulative is the promise (tests/unlock_ladder_spec), and
-- it holds for any non-negative counts at all.
local M = {}

-- What the deepest rung of the RAMPED SURPLUS deals against the shallowest -- NOT the ratio the finished
-- shelf comes out on. Every rung is handed one before the ramp sees a thing (M.shares), and that floor
-- absorbs most of this: six on the surplus is about three to one on the rung the player actually climbs.
--
-- IT IS MEASURED ON THE FOUND HALF, which is the half this curve governs. The priced half is small --
-- ten wares at the Bastion against fifty-eight finds -- and its early rungs are authored anyway: the
-- ward line is pinned at 3 and the seal line at 4 (Grade.SLOT_PINS, family shape), so no ramp factor
-- moves them. The Bastion's fifty-eight finds over fifteen tiers come out:
--
--     2   3 3 3 3 4 4 3 4 4 4 5 4 4 5 5     -- flat, and a floor of three is not an opening
--     3   2 3 3 3 3 4 3 4 4 5 4 5 5 5 5
--     4   2 3 2 3 3 4 3 4 4 5 4 5 5 5 6     -- the right span, dealt out of order
--     6   2 2 2 3 3 3 4 4 4 4 5 5 5 6 6     -- the curve, in order
--
-- Six is where the rounding stops fighting the shape: below it the ramp is shallow enough that the
-- cumulative round scatters the twos and threes, and the shelf deals three, then two, then three again.
-- Above it nothing moves -- the thin houses are already at one or two a rung and have no surplus left
-- to ramp, which is also why the Undercroft reads the same at every factor here.
M.RAMP = 6

-- The ramp itself, over a band it is known to fill: `n` spread across `rungs`, shallow end first.
local function ramp(n, rungs)
    local out = {}
    local weight, total = {}, 0
    for r = 1, rungs do
        weight[r] = 1 + (M.RAMP - 1) * (r - 1) / (rungs - 1)
        total = total + weight[r]
    end

    -- Cumulative rather than per-rung rounding: the running total tracks the exact ramp, so the error
    -- can never accumulate into a fat rung at the end the way `floor(share)` plus a remainder does.
    local acc, prev = 0, 0
    for r = 1, rungs do
        acc = acc + weight[r]
        local upto = math.floor(n * acc / total + 0.5)
        out[r] = upto - prev
        prev = upto
    end
    return out
end

-- `n` wares over `rungs` rungs, weakest rung first. Returns a list of counts, index 1..rungs, summing
-- to exactly `n`.
--
-- EVERY RUNG DEALS ONE BEFORE ANY RUNG DEALS TWO, and the ramp distributes what is left over. This is
-- the difference between a curve and a hole. A bare ramp over a band only a little bigger than the
-- ladder rounds several rungs to nothing -- and the two passes that share this curve round
-- INDEPENDENTLY, so where their zeros coincide the player climbs a class level and the shelf does not
-- move. Measured, a bare ramp left exactly one such rung (the Alchemist's second) of the 112 in the city.
--
-- A floor of one costs the ramp almost nothing where it matters, because the SURPLUS is what gets
-- ramped: a house with 58 finds over 15 tiers still deals roughly twice as many at the bottom of the
-- rift as at the mouth of it. It simply cannot deal none. Where the band is genuinely smaller than the
-- ladder -- a discipline with nine wares -- there is no floor to give and the bare ramp spreads them,
-- which is why that case is answered first.
function M.shares(n, rungs)
    if rungs <= 0 then return {} end
    if rungs == 1 then return { n } end
    if n < rungs then return ramp(n, rungs) end

    local out = ramp(n - rungs, rungs)
    for r = 1, rungs do out[r] = out[r] + 1 end
    return out
end

return M
