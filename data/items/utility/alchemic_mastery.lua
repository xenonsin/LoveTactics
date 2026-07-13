-- Alchemic Mastery: a signature reagent with no ability of its own. Like the Fire Stone
-- (data/items/utility/fire_stone.lua) it works through the 3x3 item grid -- but instead of granting
-- a tag, its aura raises the POWER of the consumables sitting adjacent to it (diagonals included).
-- A Fire Bomb next to it hits harder; an acid or a healing potion next to it does more. Build the
-- loadout around it: the charm is dead weight alone, and a bomb wants it as a neighbor.
--
-- See Combat.auraApplies / adjacencyAura and the `powerBonus` fold in Combat.useItem's fx.power.
return {
    name = "Alchemic Mastery",
    description = "A master's reagent. Adjacent consumables strike with greater power.",
    sprite = "assets/items/alchemic_mastery.png",
    type = "utility",
    tags = { "arcane" },
    class = "alchemist",
    price = 280,
    repRank = 2,
    aura = {
        appliesTo = { "consumable" }, -- only the throwables and potions it sits beside
        powerBonus = 5,               -- added to the neighbor consumable's ability Power
    },
}
