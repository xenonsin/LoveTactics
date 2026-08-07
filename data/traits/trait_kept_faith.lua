-- Kept Faith: the standing rule of the Vow of the March
-- (data/items/utility/utility_vow_of_the_march.lua). Faith held is faith that wards -- one magic defense
-- for every two points of Zeal the crusader is carrying.
--
-- WHY THE CHARM NEEDED ONE. The Vow widened Zeal to what the whole column does and stopped there: no
-- trait, no ability, nothing its own file could spend. Buy it without the Reckoning and a 400g charm
-- banked a number that never went anywhere. docs/classes.md's rule -- "what no item may be is another
-- item's on-switch" -- was enforced on spenders only, and this was one of the three bankers left on the
-- wrong side of it.
--
-- WARD RATHER THAN A BLOW, and that is the priest half of the Crusader speaking. The shelf already
-- fields the other two readings of Zeal: the Tabard heals on a kill for the Zeal held, the Savior's
-- Watch turns a wounded ally into damage and ground crossed. What none of them was, was the thing a vow
-- actually does for the man who keeps it, which is hold him together. Magic defense is also the stat
-- the fighter half brings none of -- a crusader is plate walking into a cathedral's worth of casting.
--
-- READS WITHOUT SPENDING, the Zealot's Mercy contract: the Reckoning is still the crusade's spender and
-- still empties the pool, so a full purse is a ward you are choosing not to cash. That choice is what
-- the two items are for.
--
-- ONE PER TWO POINTS, off a pool the Vow alone deepens to 10 -- so +5 at a full purse, and the purse
-- only fills at that depth because the whole column is working. Halved for the reason Still Standing is
-- halved: mitigation here is subtractive (models/balance.lua), so a point of magic defense is a point
-- off every spell, and a charm should not out-armour armour.
--
-- A LIVE PASSIVE (Trait.liveBonus -> Combat.flatStat) and pure, like every other `live` in this folder:
-- the ward has to fall the instant the Reckoning spends the faith that raised it.
return {
    name = "Kept Faith",
    description = "Gains magic defense for every two points of Zeal held.",
    live = function(ctx)
        local n = require("models.combat").chargePool(ctx.unit, "zeal")
        if n < 2 then return nil end
        return { magicDefense = math.floor(n / 2) }
    end,
}
