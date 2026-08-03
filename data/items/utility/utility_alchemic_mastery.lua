-- Alchemic Mastery: a signature reagent with no ability of its own. Like the Fire Stone
-- (data/items/consumable/consumable_fire_stone.lua) it works through the 3x3 item grid -- but instead of granting
-- a tag, its aura raises the MAGNITUDE of the consumables sitting adjacent to it (diagonals included).
-- A Fire Bomb next to it hits harder; an acid or a healing potion next to it does more. Build the
-- loadout around it: the charm is dead weight alone, and a bomb wants it as a neighbor.
--
-- See Combat.auraApplies / adjacencyAura and the `amountBonus` fold in Combat.useItem's fx.amount.
local Curve = require("models.curve")

return {
    name = "Alchemic Mastery",
    description = "Adjacent consumables hit harder.",
    flavor = "Dead weight on its own. Every bomb in the satchel would like to sit beside it.",
    sprite = "assets/items/alchemic_mastery.png",
    type = "utility",
    tags = { "arcane" },
    class = "alchemist",
    price = 280,
    unlockQuests = 3,
    aura = {
        appliesTo = { "consumable" }, -- only the throwables and potions it sits beside
        amountBonus = Curve.ramp(5),              -- added to the neighbor consumable's ability magnitude
    },
}
