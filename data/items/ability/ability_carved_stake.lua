-- Carved Stake: the hunter half of the Totemist (hunter x priest). Drives a Totem into a tile
-- (data/characters/character_totem.lua) and lays a 3x3 warding zone around it (data/hazards/
-- hazard_shared_bulwark.lua -- every ally standing in it carries a physical barrier that swallows a
-- blow). The priest's ward carved into a stake and planted where the Lodge wants the line held --
-- static ground control, alive until the stake is cut down. Requires an adjacent bow in the grid.
return {
    name = "Carved Stake",
    description = "Plants a warding totem whose 3x3 zone gives allies a barrier that swallows a blow. Needs an adjacent bow.",
    flavor = "The Cathedral blesses a shield. The Lodge blesses a stick and hammers it where the shield would have stood.",
    sprite = "assets/items/ability_carved_stake.png",
    type = "ability",
    tags = { "summon" },
    class = "hunter",
    discipline = "totemist", -- hunter x priest; the Ward-totems mechanic's first stock
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        support = true,
        cost = { stat = "stamina", amount = 12 },
        requiresAdjacent = { type = "weapon", tag = "bow" },
        effect = function(fx)
            local totem = fx.summon("character_totem", fx.tx, fx.ty, {
                control = "none", timeless = true, scaling = { health = 3 }, amount = fx.level,
            })
            if totem and totem.alive then
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_shared_bulwark", { owner = totem, duration = 9999 })
                    end
                end
            end
        end,
    },
}
