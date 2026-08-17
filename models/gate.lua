-- THE GATE: the town at the mouth of the descent, and the half of the loop that is not a floor.
--
-- Wizardry's castle is not decoration on its dungeon, it is the other side of it: an expedition ends by
-- walking back to the stair, and what makes that walk worth making is that there is somewhere to spend
-- what you carried out and somewhere to put what you carried out on a stretcher. Without it the descent
-- was a single push with no reason to ever stop pushing, which is what the extraction prompt kept
-- failing to be (see models/descent.lua's Descent.account on why that button was hollow).
--
-- THREE COUNTERS, and each answers a cost the floors impose that the floors cannot undo:
--
--   the inn      wounds. Falling in a fight caps a body's healing for the rest of its life
--                (models/wound.lua) and nothing underground sets a bone. The inn is the only mender.
--   the temple   the dead. A WIPE leaves the whole company on the floor it fell on, to be carried
--                out by whoever goes down next (the rescue stop); the temple is what turns a body in
--                a sack back into somebody who can hold a sword.
--   the store    everything else, and deliberately almost nothing: a descent's gear comes off its
--                FLOORS, so the shelf is draughts and a spare blade (data/vendors/gate_store.lua).
--
-- PURE MODEL. No love.graphics, no state switching -- the prices, the eligibility and the spends live
-- here so a spec can drive them, and states/gate.lua is the screen over the top. Same split
-- models/descent.lua keeps against states/descent.lua.

local Gate = {}

-- ---------------------------------------------------------------------------
-- The inn
-- ---------------------------------------------------------------------------

-- WHAT A NIGHT COSTS, per body in the company. Priced per head rather than flat because the company
-- grows from one to four over the first circles, and a flat bill would be crushing at the mouth and
-- pocket change by the seventh -- which is backwards, since a full company is exactly when a night is
-- worth most.
--
-- Deliberately cheaper than mending. A rest is the thing you do every time you come up; setting a bone
-- is the thing you save for, and Wound.MEND_COST is what that costs.
Gate.INN_PER_HEAD = 25

function Gate.innPrice(player)
    local n = #((player and player.roster) or {})
    return math.max(Gate.INN_PER_HEAD, n * Gate.INN_PER_HEAD)
end

-- A night at the inn: everything restored, every wound set.
--
-- BOTH, for one bill, and that is a departure from the campaign worth naming. The city heals free and
-- charges per wound (Wound.mend), because there the company is permanent and a wound is a scar you
-- choose to carry. A descent company is four bodies deep with no bench: a wounded one is not a body
-- you field around, it is a quarter of your fighting strength at a fraction of its health, and pricing
-- each one separately would just mean a player who could not afford the second one stopped descending.
--
-- Returns true, or false plus a reason ("gold", "nobody").
function Gate.rest(player)
    if not (player and player.roster and #player.roster > 0) then return false, "nobody" end
    local Player = require("models.player")
    local price = Gate.innPrice(player)
    if (player.gold or 0) < price then return false, "gold" end
    Player.spendGold(player, price)
    -- Wounds first: Player.restore reads the wound cap when it refills, so clearing them in the other
    -- order would top everybody up to their WOUNDED ceiling and then remove the ceiling, leaving a
    -- rested company short and the bill paid.
    player.wounds = {}
    Player.restore(player)
    return true
end

-- ---------------------------------------------------------------------------
-- Going back down
-- ---------------------------------------------------------------------------

-- Can this company descend at all? One living body is the whole test -- a descent opens with exactly
-- one hire is the whole test: the player is a tactician and stands in no company (models/descent.lua),
-- so a descent opens EMPTY and the gate is where it stops being empty.
function Gate.canDescend(player)
    return #((player and player.roster) or {}) > 0
end

return Gate
