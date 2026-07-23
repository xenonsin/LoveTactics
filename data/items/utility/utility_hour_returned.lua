-- The Hour Returned: every recharging thing its bearer owns is simply not recharging any more.
--
-- THE ONLY ITEM IN THE GAME THAT GIVES AN ACTION BACK rather than making one bigger, and that is a
-- genuinely different axis to buy on. Everything else in this catalog raises a number, opens a window,
-- or moves a body; this raises nothing and moves nobody. What it does is un-spend the turn you already
-- spent -- the guard that fired, the signature that unlocked and locked again, the reflex on its long
-- cooldown, the one-per-battle answer. All of them, at once.
--
-- Which makes its value entirely a property of the LOADOUT rather than of the item. In a grid of
-- cheap fast abilities it does nothing worth the mana. In a grid built around one enormous
-- once-a-battle relic -- a Stayed Hand, a signature, a guard with a sixty-tick recharge -- it is worth
-- exactly that relic a second time, which is more than any other single item on the shelf can promise.
--
-- It wipes the trait cooldowns and the per-item reflex timers together, because in this model those
-- are one table keyed two ways (see Combat.clearCooldowns, which exists precisely so nothing can wipe
-- half of it). It does NOT refund mana, stamina, or a spent consumable stack: it returns the HOUR, and
-- the price of the thing was never the hour.
--
-- ADJACENCY: it is worth more beside a full grid, and says so honestly rather than mechanically -- the
-- item has no adjacency gate at all. That is deliberate. Every other new item here argues with the
-- grid, and this one argues with the CLOCK, which is the one resource the grid cannot buy.
return {
    name = "The Hour Returned",
    description = "Clears every cooldown and reflex timer its bearer is waiting on.",
    flavor = "The Arcanum sold three. It has spent two hundred years insisting there were only ever two.",
    sprite = "assets/items/utility_hour_returned.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 560,
    repRank = 4,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        cost = { stat = "mana", amount = 24 },
        support = true,
        effect = function(fx)
            local cleared = fx.clearCooldowns(fx.user)
            if cleared > 0 then
                fx.log("action", string.format("%s takes the hour back (%d ready again).",
                    fx.user.char and fx.user.char.name or "Unit", cleared), fx.user)
            else
                fx.log("action", "There was nothing left to wait for.", fx.user)
            end
        end,
    },
}
