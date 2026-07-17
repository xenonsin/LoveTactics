-- Flash Bomb: a blinding burst thrown at a foe and detonating around it, like Acid Bomb. Everything
-- caught in the flash is Blinded (data/status/blind.lua) -- ability range cut short -- with no damage
-- of its own: the point is to shut down a cluster of archers or casters, not to hurt them. The blast
-- hits allies too, so mind your own line.
return {
    name = "Flash Bomb",
    description = "Inflicts Blind on everything in the target area. Deals no damage.",
    flavor = "A rogue's apology to a line of archers: they never do see who was leaving.",
    sprite = "assets/items/flash_bomb.png",
    type = "consumable",
    tags = { "flash" },
    class = "rogue",
    price = 120,
    repRank = 1,
    activeAbility = {
        target = "tile", -- thrown at a foe and bursts around it, like Acid Bomb / Fireball
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.applyStatus(u, "status_blind")
            end
        end,
    },
}
