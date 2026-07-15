-- Blessing: the priest calls down a benediction over a 3x3 area, granting every ally within the
-- Blessing status (data/status/blessing.lua) -- a flat lift to Damage and Magic Damage for a while.
-- Enemies in the blast gain nothing. The offensive half of the priest's two field buffs (compare
-- Aegis). A ground-target support cast, so its footprint previews green.
return {
    name = "Blessing",
    description = "Bless allies in an area, raising their Damage and Magic Damage.",
    sprite = "assets/items/ability_blessing.png",
    type = "ability",
    tags = { "holy", "restorative" },
    class = "priest",
    price = 280,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        support = true,
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" }, -- 3x3 blessed area
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side == fx.user.side then
                    fx.applyStatus(u, "blessing")
                end
            end
        end,
    },
}
