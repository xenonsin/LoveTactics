-- The Stormglass Rod: a hollow glass shaft with weather in it. Point it at anybody -- theirs or yours
-- -- and a column of air takes them off the board for a while (data/status/status_suspended.lua).
--
-- The item form of Updraft, and the two are deliberately not the same purchase. The spell is a mage's
-- ability, gated on an arcane neighbour, priced in mana, and forged along one axis. The rod is a
-- CHARM -- anyone can carry it, it asks nothing of the grid around it, and it is bought from the
-- general shelf. That is the whole reason it exists: suspension is the one control in this game that
-- protects what it lands on, and a party with no mage should still be able to rescue somebody.
--
-- Which is what makes it the most-used item on this list, and the most misused. A suspension is a
-- spell with no obvious side:
--
--   * On the ALLY three enemies have converged on, it is the cheapest rescue in the catalog. Nothing
--     reaches them while they hang, and the enemy spends its turns on empty ground.
--   * On the ENEMY heavy piece, it is two turns of that piece not existing -- and two turns of your
--     own archers not being able to shoot it either.
--   * On the enemy you were ABOUT to kill, it is a full turn thrown away and a life saved. This is
--     the mistake everybody makes once.
--
-- Slower than the spell (speed 4 against 3) and pricier per use, because a charm that anybody can
-- carry should not also be the efficient version. What it buys is availability.
return {
    name = "The Stormglass Rod",
    description = "Lifts one body out of the fight: it cannot act, answer, move, or be targeted.",
    flavor = "Sealed weather, and a merchant's promise that the seal has held for eighty years.",
    sprite = "assets/items/utility_stormglass_rod.png",
    type = "utility",
    tags = { "arcane" },
    price = 380, -- no class: the general store stocks it, and anybody may carry one
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 16 },
        support = true,
        effect = function(fx)
            local lifted = fx.unitAt(fx.tx, fx.ty)
            if not lifted then return end
            fx.applyStatus(lifted, "status_suspended", { duration = 10 + fx.level })
        end,
    },
}
