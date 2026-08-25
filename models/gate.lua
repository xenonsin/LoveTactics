-- THE GATE: the town at the mouth of the descent, and the half of the loop that is not a floor.
--
-- Wizardry's castle is not decoration on its dungeon, it is the other side of it: an expedition ends by
-- walking back to the stair, and what makes that walk worth making is that there is somewhere to spend
-- what you carried out and somewhere to put what you carried out on a stretcher. Without it the descent
-- was a single push with no reason to ever stop pushing, which is what the extraction prompt kept
-- failing to be (see models/descent.lua's Descent.account on why that button was hollow).
--
-- ONE COUNTER, answering the one cost the floors impose that the floors cannot undo:
--
--   the inn      wounds, and it is a BED rather than a counter. Falling in a fight caps a body's
--                healing (models/wound.lua) and nothing underground sets a bone; you leave them here,
--                pay for the stay, and they mend a wound a day while they are out of the company
--                (Gate.lodge). Gold opens the door and cannot buy back the days.
--
-- TWO OF THESE WERE PROSE AND NOTHING ELSE, which is worth recording because they read for a long time
-- as things the game had:
--
--   the temple   was described here as what "turns a body in a sack back into somebody who can hold a
--                sword", carried out by a rescue stop on a later dive. Neither was ever written. A wipe
--                does not leave bodies underground -- the company wakes here, wounded, and only the HAUL
--                stays on the floor (states/game.lua's onLoss). Stranding was designed in full during
--                the descent-loop pass and cut: an absent body dominates a degraded one, so it would
--                have made the wound ladder decoration.
--
--   the store    "draughts and a spare blade" off data/vendors/gate_store.lua. There is no store at this
--                screen; the shops are cards in the city (states/markets.lua).
--
-- PURE MODEL. No love.graphics, no state switching -- the prices, the eligibility and the spends live
-- here so a spec can drive them, and states/gate.lua is the screen over the top. Same split
-- models/descent.lua keeps against the screens that draw it.

local Gate = {}

-- ---------------------------------------------------------------------------
-- The inn
-- ---------------------------------------------------------------------------

-- WHAT A NIGHT COSTS, per body FIELDED. Priced per head rather than flat because the company grows
-- from one to four over the first circles, and a flat bill would be crushing at the mouth and pocket
-- change by the seventh -- which is backwards, since a full company is exactly when a night is worth
-- most.
--
-- Deliberately cheap. A rest is the thing you do every time you come up, and it sets no bones at all:
-- mending is a stay in a bed, priced per wound (Gate.LODGE_PER_WOUND below).
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

-- A night at the inn: health and mana back, and NOT a single bone set.
--
-- IT USED TO CLEAR THE WHOLE LEDGER -- `player.wounds = {}` -- for one bill of at most a hundred, which
-- made it by far the cheapest way to undo a wound in the game and quietly the only one that mattered.
-- Wound.mend was deleted for being a counter you could settle a wound at; this was the same thing at a
-- better price, and it survived the cut because nothing named it in the same breath.
--
-- SO THE TWO ARE SPLIT, and the split is the whole point. A NIGHT tops a company back up: it is the
-- thing you do every time you come up, it is cheap, and it touches resources only. A BED mends: you
-- leave a body here, pay per wound, and they are out of the company a day for each one (Gate.lodge).
-- Gold buys the first and opens the door to the second; it cannot buy back the days.
--
-- Returns true, or false plus a reason ("gold", "nobody").
function Gate.rest(player)
    if not (player and player.roster and #player.roster > 0) then return false, "nobody" end
    local Player = require("models.player")
    local price = Gate.innPrice(player)
    if (player.gold or 0) < price then return false, "gold" end
    Player.spendGold(player, price)
    -- Player.restore reads each body's wound cap as it refills, so a wounded body tops up to its
    -- WOUNDED ceiling and no further. That is now the honest result rather than an ordering hazard:
    -- the night gives back what the fighting cost, and the wound is still a wound.
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
