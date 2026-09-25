-- GILDER'S LEAF: the Dwarf Goldsmith's trick with both edges kept, and it drops off the Goldsmith as a
-- mammonite's piece (reviewed 2026-09-24, "The Dwarves of Greed").
--
-- Plates any body in gold (data/status/status_gilded.lua): +3 Defense, -1 Movement, -2 Speed. On an ally
-- it is armour that costs a step. On a foe it is a slow -- and a foe that falls gilded pays 20 gold into
-- the spoils, which is the mammonite's reading of it: gold that was always on the body, prised off.
-- Dwarves go for a gilded body first, so on a dwarf fight gilding one of your own is choosing the bait.
--
-- `support = true` reads it as a kindness, and `aimsEither` lets the enemy planner aim it both ways: on
-- a kinsman as armour, and on the company's front-liner as bait (round 3 approved both, 2026-09-24). A
-- player aims it at anybody.
return {
    name = "Gilder's Leaf",
    description = "Gilds a body: increase defense, reduce movement and speed. A foe that falls gilded pays 20 gold.",
    flavor = "Gold leaf is beaten thinner than breath. It still weighs more than the one wearing it expected.",
    sprite = "assets/items/ability_gilders_leaf.png",
    type = "ability",
    tags = { "guile" },
    class = "mammonite",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "unit",
        range = 3,
        speed = 3,
        support = true,
        aimsEither = true,
        cooldown = 10,
        cost = { stat = "mana", amount = 6 },
        effect = function(fx)
            if fx.target then fx.applyStatus(fx.target, "status_gilded", { applier = fx.user }) end
        end,
    },
}
