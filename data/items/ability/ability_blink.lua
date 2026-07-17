-- Blink: not a cast but a MODE. Activating it in the grid toggles the carrier's movement from a walk
-- into a teleport for the battle (a free, turn-neutral flip -- see states/battle.lua and
-- Combat.blink). While it is on and the carrier can pay one jump, its move reaches farther (movement
-- 5), ignores terrain cost and anything in the way, and spends mana instead of move initiative -- but
-- a blink it can't afford quietly becomes an ordinary walk, so toggling it on is never a trap.
--
-- It carries a `moveBehavior` rather than an `activeAbility`, exactly as the Focus/Defend stones carry
-- a `waitBehavior`: an item that changes how a verb behaves, not one that adds an action. So it feeds
-- no initiative and never sits in the ability cycle -- it is a stance the mage steps into and out of.
return {
    name = "Blink",
    description = "Toggle: your movement becomes a teleport, paid in mana per jump.",
    flavor = "The Arcanum regards walking as a confession.",
    sprite = "assets/items/ability_blink.png",
    type = "ability",
    tags = { "arcane" },
    class = "mage",
    price = 300,
    repRank = 3,
    moveBehavior = {
        mode = "teleport",
        movement = 5, -- teleport reach while armed (vs. the caster's walking movement)
        cost = { stat = "mana", amount = 6 }, -- spent per jump
    },
}
