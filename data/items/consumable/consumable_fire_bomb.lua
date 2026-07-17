-- Crucible rank-1. A clay pot of volatile powder: bursts in a small blast and leaves everything
-- caught in it burning (data/status/burn.lua). The Flask of Liquid Fire's cheaper cousin -- where
-- the flask paints the GROUND with a lingering fire hazard for area denial, the bomb sets the FOES
-- alight directly, so it wants bodies clustered, not a corridor to close off. Carries no "magical"
-- tag: the fire is chemistry, and does the same to a wizard as to a knight.
--
-- The natural first neighbor for the Crucible's charms -- an Alchemic Mastery, Long-Fuse Reagent, or
-- Everflask sitting beside it in the grid turns a cheap pot into a real threat.
return {
    name = "Fire Bomb",
    description = "Deals fire damage in the target area and inflicts Burn.",
    flavor = "The Crucible sells it by the crate. The fire is chemistry, and it does the same to a wizard as to a knight.",
    sprite = "assets/items/fire_bomb.png",
    type = "consumable",
    tags = { "fire" }, -- no "magical": the fire is chemistry, and cares nothing for magic defense
    class = "alchemist",
    price = 70,
    repRank = 1,
    activeAbility = {
        target = "tile", -- thrown at a foe and bursts around it, like Fireball
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        damage = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }, -- flat: nothing about the thrower makes the fire hotter
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "status_burn")
            end
        end,
    },
}
