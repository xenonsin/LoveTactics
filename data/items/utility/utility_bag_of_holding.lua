-- Pim's bound relic (Thief). It is a bag, and then it is a weapon.
--
-- IT EXISTS BECAUSE A LIFT HAD NOWHERE TO GO. Combat.steal tries the thief's grid and then dropped to
-- the party stash -- and the stash is out of the battle, so on a nine-cell grid already carrying a
-- build, "steal it" mostly meant "remove it from play". Fine for a denial tool, useless for a
-- signature whose whole payoff is USING what you took. Now a theft lands here instead (see the branch
-- in Combat.steal and the block above Item.bagRoom), and stays in the fight.
--
-- ONE CONTROL, TWO JOBS, and which one you get is decided by the gate rather than by a second button:
-- while the signature is still locked, pressing the slot OPENS the bag (ui/panels/bag.lua) so she can
-- take something out and use it this turn. Once three things are in it the same press empties the whole
-- thing at once. A greyed slot that opens a bag is strictly better than a greyed slot that prints a
-- refusal, which is the whole argument for wiring it that way (states/battle.lua's armItem).
--
-- WHAT THE PAYOFF DOES NOT DO, said plainly rather than implied: it does not consume what is inside.
-- Every stolen thing is still hers afterwards. The blow is measured by how much she is carrying, which
-- is the honest reading of "the bag goes off" and keeps the effect free of the item-moving mutations a
-- damage preview would have to replay.
return {
    name = "The Bag of Holding",
    description = "Holds what you steal. Empties into every foe near you, scaled by how much is in it.",
    flavor = "She has never once opened it in front of the person it belongs to.",
    sprite = "assets/items/sig_bag_of_holding.png",
    type = "utility",
    tags = { "signature", "impact" },
    class = "rogue",
    discipline = "thief",
    -- Six, which is two thirds of a grid: enough that a good fight's takings all fit, small enough
    -- that a long one still makes her decide what to carry out.
    bag = { capacity = 6 },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 9 },
        aoe = { radius = 2, shape = "square" },
        description = "Throws everything in the bag at every foe within 2.",
        unlock = { event = "stolen", count = 3, text = "Take 3 things" },
        effect = function(fx)
            -- Everything she is carrying, thrown at once. The count is read off the bag rather than
            -- off the tally so what lands is what is actually in her hands right now -- taking things
            -- out through the panel makes the blow smaller, which is the trade the panel is for.
            local carried = #((fx.item and fx.item.contents) or {})
            if carried <= 0 then return end
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.damage(u, { amount = (fx.amount or 0) + 6 + carried * 6 })
                end
            end
        end,
    },
    -- a bag that keeps what you took
    bonus = { luck = 2 },
}
