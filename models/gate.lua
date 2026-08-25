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

-- WHAT A NIGHT COSTS, per body FIELDED. Priced per head rather than flat because the company grows
-- from one to four over the first circles, and a flat bill would be crushing at the mouth and pocket
-- change by the seventh -- which is backwards, since a full company is exactly when a night is worth
-- most.
--
-- Deliberately cheaper than mending. A rest is the thing you do every time you come up; setting a bone
-- is the thing you save for, and Wound.MEND_COST is what that costs.
--
-- PER FIELDED HEAD RATHER THAN PER ROSTER HEAD, and that distinction did not exist until the Hiring
-- Hall started dealing (models/voucher.lua). The roster used to BE the field -- four, capped -- so "the
-- company" had one meaning and this counted it. A roster is deep now and a pull adds to it, so counting
-- roster heads would price a night at three hundred and seventy-five for a player who had been lucky,
-- and a bill that climbs with how many people you have COLLECTED is a tax on collecting them. What the
-- inn is for is the four who went down, so it bills the four who went down.
Gate.INN_PER_HEAD = 25

-- ---------------------------------------------------------------------------
-- The Inn: a bed, and what it costs to put somebody in one
-- ---------------------------------------------------------------------------

-- WHAT A STAY COSTS, per wound. Paid once, at the door, for the whole stay -- so a three-wound body is
-- three times this and three days in a bed, and the player sees the whole bill before agreeing to it.
--
-- Per WOUND rather than per night, because a nightly charge is the same total arriving in instalments
-- and adds a way to fail halfway: a company that ran out of gold on day two would have somebody turned
-- out mid-mend, which is a rule nobody wants to discover. One price, one decision.
--
-- Priced against an errand's purse (a 250g median) rather than against the shelf: a full three-wound
-- stay is most of a day's takings, which is what makes "go short-handed instead" a real answer.
Gate.LODGE_PER_WOUND = 60

-- What lodging `charId` would cost right now. Zero for a body with nothing to mend -- the Inn does not
-- take money for a bed nobody needs.
function Gate.lodgePrice(player, charId)
    local Wound = require("models.wound")
    return Wound.count(player, charId) * Gate.LODGE_PER_WOUND
end

-- Is this body in a bed? A lodged body is NOT in the company: it cannot be picked for an expedition
-- (Descent.party filters them out), which is the real cost of the stay.
function Gate.isLodged(player, charId)
    return ((player or {}).atInn or {})[charId] == true
end

-- Everybody currently in a bed, as ids in roster order -- so a surface listing them agrees with every
-- other surface that lists the company.
function Gate.lodged(player)
    local out = {}
    for _, char in ipairs((player or {}).roster or {}) do
        if Gate.isLodged(player, char.id) then out[#out + 1] = char.id end
    end
    return out
end

-- Put a body to bed, for coin. Returns true, or false plus a reason ("unhurt" | "gold" | "already").
--
-- Charged in full on arrival, and NOT refunded on the way out: a bed taken is a bed paid for, and a
-- player who checked somebody out a day early to get half their money back would be playing the ledger
-- rather than the company.
function Gate.lodge(player, charId)
    if not (player and charId) then return false, "unhurt" end
    if Gate.isLodged(player, charId) then return false, "already" end
    local price = Gate.lodgePrice(player, charId)
    if price <= 0 then return false, "unhurt" end
    if (player.gold or 0) < price then return false, "gold" end

    local Player = require("models.player")
    Player.spendGold(player, price)
    player.atInn = player.atInn or {}
    player.atInn[charId] = true
    return true
end

-- Take somebody out of a bed, mended or not. Free, and deliberately allowed mid-stay: a company that
-- suddenly needs a fourth body should be able to pull one out half-healed and pay for it in wounds.
function Gate.checkout(player, charId)
    if not (player and player.atInn) then return false end
    if not player.atInn[charId] then return false end
    player.atInn[charId] = nil
    if next(player.atInn) == nil then player.atInn = nil end
    return true
end

-- A body whose last wound has just been set walks out on its own. Called on the same beat the day
-- advances, so a mended body is back in the company by the time the player looks at it -- leaving them
-- lodged at zero wounds would be a bed that has to be swept up by hand, and a company one short for a
-- reason the screen no longer shows.
function Gate.dischargeMended(player)
    local Wound = require("models.wound")
    local out = {}
    for _, id in ipairs(Gate.lodged(player)) do
        if Wound.count(player, id) <= 0 then
            Gate.checkout(player, id)
            out[#out + 1] = id
        end
    end
    -- WALKING OUT OF A BED IS WALKING OUT WHOLE. Setting the last bone gives the reserved share back
    -- (models/wound.lua), but the pool it un-reserves is still only as full as it was -- so without
    -- this a body leaves the Inn at the health they went in with and the player has paid for a number
    -- that did not move. Wound.mend used to restore for exactly this reason; the beat moved, the
    -- obligation did not.
    if #out > 0 then require("models.player").restore(player) end
    return out
end

function Gate.innPrice(player)
    local Player = require("models.player")
    local n = math.min(#((player and player.roster) or {}), Player.MAX_FIELD)
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
-- Can this company descend at all? SOMEBODY PICKED, which with no run and no picks is the first four of
-- the roster (Descent.party), so a company that has never opened this screen still has a stair.
--
-- It used to ask only whether the roster was non-empty, which was the same question while everybody
-- walked down. The expedition is four now and chosen, so a player who has unticked the last name is
-- standing at a stair with nobody to send -- and the honest answer is that the stair does not open,
-- rather than that it opens onto an empty board.
function Gate.canDescend(player, run)
    if #((player and player.roster) or {}) == 0 then return false end
    return #require("models.descent").party(run, player) > 0
end

return Gate
