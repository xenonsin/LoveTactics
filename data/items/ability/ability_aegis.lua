-- Aegis: the priest raises a warding light over a 3x3 area, granting every ally within the Aegis
-- status (data/status/aegis.lua) -- a flat lift to Defense and Magic Defense for a while. Enemies in
-- the blast gain nothing. The shielding half of the priest's two field buffs (compare Blessing). A
-- ground-target support cast (target = "tile", allowOccupied, support) so its footprint previews green.
return {
    name = "Aegis",
    description = "Wards allies in an area, raising their Defense and Magic Defense.",
    flavor = "The Cathedral's light does not ask who deserves it, only who is standing close enough.",
    sprite = "assets/items/ability_aegis.png",
    type = "ability",
    tags = { "holy", "protective" },
    class = "priest",
    price = 260,
    repRank = 2,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        support = true, -- friendly area cast: preview green
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" }, -- 3x3 warded area
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side == fx.user.side then
                    fx.applyStatus(u, "status_aegis")
                end
            end
        end,
    },
}
