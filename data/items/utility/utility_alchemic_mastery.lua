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
    description = "Increases the amount every adjacent consumable deals or heals.",
    flavor = "Dead weight on its own. Every bomb in the satchel would like to sit beside it.",
    sprite = "assets/items/alchemic_mastery.png",
    type = "utility",
    tags = { "arcane" },
    class = "alchemist",
    price = 330,
    unlockQuests = 3,
    -- MASTERY, and the stat of the same name. The aura lends the neighbour a bigger number; the Skill is
    -- the hand that throws it -- and a thrown flask rolls to hit like anything else aimed at an
    -- unwilling body. "Dead weight on its own" stays true: this is still an item whose whole point is
    -- what it sits beside.
    --
    -- The Crucible now sells both ends of accuracy, which is the shelf arguing with itself as an envy
    -- shelf should: the Wine it stocks costs the drinker three points of Skill (data/status/drunk).
    bonus = { skill = 2 },
    aura = {
        appliesTo = { "consumable" }, -- only the throwables and potions it sits beside
        amountBonus = Curve.ramp(5, 15),              -- added to the neighbor consumable's ability magnitude
    },
}
