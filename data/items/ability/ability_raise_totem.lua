-- Raise Totem: the priest half of the Totemist (hunter x priest). Raises a Totem on a tile
-- (data/characters/character_totem.lua) and consecrates a 3x3 around it (data/hazards/hazard_heal.lua --
-- allies standing on it Regenerate). Sanctuary made permanent and portable-by-planting: the blessing
-- holds as long as the totem stands, so the priest can leave hallowed ground behind instead of casting
-- it turn after turn. Cut the totem down to lift the zone.
return {
    name = "Raise Totem",
    description = "Raises a healing totem whose 3x3 zone Regenerates allies who stand within. Cut it down to lift it.",
    flavor = "A priest cannot be everywhere. A totem is the priest's way of having already been.",
    sprite = "assets/items/ability_raise_totem.png",
    type = "ability",
    tags = { "holy", "summon", "restorative" },
    class = "priest",
    discipline = "totemist", -- hunter x priest; the Ward-totems mechanic's first stock
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        support = true,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            local totem = fx.summon("character_totem", fx.tx, fx.ty, {
                control = "none", timeless = true, scaling = { health = 3 }, amount = fx.level,
            })
            if totem and totem.alive then
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_heal", { amount = 5 + fx.level, owner = totem, duration = 9999 })
                    end
                end
            end
        end,
    },
}
