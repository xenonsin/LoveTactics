-- Sacred Banner: a holy standard the priest raises on open ground. While it stands, every ally in the
-- 3x3 square around it is Blessed (data/status/blessing.lua) -- a lift to Damage and Magic Damage,
-- refreshed each round. The offensive cousin of the Rally Banner (which spreads Inspiration): same
-- destructible standard (data/characters/banner.lua), same one-per-relic rule, aimed at an empty tile.
-- See data/items/ability/ability_rally_banner.lua for how the banner and its aura work.
return {
    name = "Sacred Banner",
    description = "Plant a holy banner that blesses nearby allies, raising their Damage and Magic Damage while it stands.",
    sprite = "assets/items/ability_sacred_banner.png",
    type = "ability",
    tags = { "banner", "holy" },
    class = "priest",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 5,
        support = true,
        cost = { stat = "mana", amount = 16 },
        effect = function(fx)
            local banner = fx.summon("banner", fx.tx, fx.ty, { control = "none", timeless = true })
            if banner and banner.alive then
                -- The 3x3 of Sacred Ground the standard holds open; see ability_rally_banner.lua.
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_sacred", { owner = banner })
                    end
                end
            end
        end,
    },
}
