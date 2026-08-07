-- Still Standing: the standing rule of Crowd's Favour (data/items/utility/utility_crowds_favour.lua).
-- The Champion stands harder for the punishment it is already carrying -- one defense for every two
-- points of Defiance held, read off the pool as it stands right now.
--
-- WHY THE CHARM NEEDED ONE. docs/classes.md closes half a mechanic in one direction only: "a spender
-- declares the pool it spends", so Answering Blow banks its own Defiance and works the day you buy it.
-- Nothing said the same of a BANKER, and Crowd's Favour was the other half of that same sale -- a 380g
-- charm with no trait and no effect, deepening and widening a pool that nothing in its own file could
-- spend. Bought alone it did nothing whatsoever. What no item may be is another item's on-switch, and
-- Answering Blow was quietly this one's.
--
-- READS THE POOL WITHOUT SPENDING IT, exactly as Zealot's Mercy reads Zeal beside the Reckoning: the
-- interest a pool pays while you hold it. That is also what turns the Champion's cash-in into a real
-- decision -- Answering Blow consumes ALL of it, so the blow drops the guard the same instant it lands.
-- A Champion sitting on a full pool is not playing wrong; they are playing the wall.
--
-- A LIVE PASSIVE (Trait.liveBonus, folded into Combat.flatStat), not a banked one, for the reason
-- trait_formation_fighter's header records: the pool goes DOWN as well as up, and a bonus banked when
-- the eighth blow landed would still be paying out two turns after the pool was emptied. `live` must
-- stay PURE -- chargePool is a read (banked tallies less what was spent), it touches nothing, which is
-- what lets both damage previews and the inventory tooltip call it on every hover frame.
--
-- ONE PER TWO POINTS, not one per point. The pool caps at 8 with the whole Champion shelf carried, and
-- +8 defense is a second suit of armour hung on a charm. +4 is a shield's worth for standing in the
-- line all fight, which is what the item is for. Mitigation in this game is subtractive, so defense and
-- weapon power are the same quantity (models/balance.lua) -- the halving is the whole difference
-- between a charm and a chestplate.
return {
    name = "Still Standing",
    description = "Gains defense for every two points of Defiance held.",
    live = function(ctx)
        local n = require("models.combat").chargePool(ctx.unit, "defiance")
        if n < 2 then return nil end
        return { defense = math.floor(n / 2) }
    end,
}
