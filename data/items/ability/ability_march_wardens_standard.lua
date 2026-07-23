-- March-Warden's Standard: the knight half of the Warden (knight x hunter). Drives a March Standard into
-- a tile (data/characters/character_field_standard.lua) and lays a 3x3 of Halting Ground around it
-- (data/hazards/hazard_halting_ground.lua) -- every foe that crosses is Halted, its turn taken. The
-- knight's "where do we stand" nailed to a square of the far field: a border a charge cannot pass
-- without stopping, held open until the standard is cut down. Modeled on ability_rally_banner.
return {
    name = "March-Warden's Standard",
    description = "Plants a standard whose 3x3 of ground Halts any foe that crosses it. Cut it down to lift the zone.",
    flavor = "The March does not hold the line with bodies. It teaches a patch of ground to say no.",
    sprite = "assets/items/ability_march_wardens_standard.png",
    type = "ability",
    tags = { "summon" },
    class = "knight",
    discipline = "warden", -- knight x hunter; the Lockdown-zone mechanic's first stock
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        support = true,
        cost = { stat = "stamina", amount = 12 },
        effect = function(fx)
            local standard = fx.summon("character_field_standard", fx.tx, fx.ty, {
                control = "none", timeless = true, scaling = { health = 3 }, amount = fx.level,
            })
            if standard and standard.alive then
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_halting_ground", { owner = standard, duration = 9999 })
                    end
                end
            end
        end,
    },
}
