-- A brass canister that bursts in a 3x3 and stuns everything caught in it (data/status/stun.lua):
-- each victim is shoved down the turn order, its next turn delayed. Like the Flash Bomb and Ice Bomb
-- the control IS the payload -- no damage of its own, just a cluster of foes knocked out of tempo
-- while your line closes. Shorter-lived than the Ice Bomb's freeze and without the crush/fire
-- vulnerability, but it needs nothing to follow up: a stun stands on its own.
--
-- The blast catches allies too, so mind your own line. Carries the "lightning" tag -- a Wet foe
-- caught in it has no armor for the jolt, but the bomb deals no damage to amplify, so the tag is
-- mostly flavor here (compare a lightning WEAPON, where Wet's vulnerability bites).
return {
    name = "Lightning Bomb",
    description = "A crackling canister. Bursts and stuns everything caught in the blast.",
    sprite = "assets/items/lightning_bomb.png",
    type = "consumable",
    tags = { "lightning" },
    class = "alchemist",
    price = 160,
    repRank = 2,
    activeAbility = {
        target = "enemy", -- thrown at a foe and bursts around it, like Fire Bomb / Ice Bomb
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" }, -- 3x3 stunned area
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.applyStatus(u, "stun")
            end
        end,
    },
}
