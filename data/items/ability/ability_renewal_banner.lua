-- Renewal Banner: a mending standard the priest raises on open ground. While it stands, every ally in
-- the 3x3 square around it gains Regeneration (data/status/regen.lua) -- flat health recovered at the
-- start of each of their turns, refreshed while they hold the ground beside it. The restorative cousin
-- of the Rally and Sacred banners: same destructible standard (data/characters/banner.lua), same
-- one-per-relic rule, aimed at an empty tile. See data/items/ability/ability_rally_banner.lua for how
-- the banner and its aura work.
return {
    name = "Renewal Banner",
    description = "Plant a mending banner that regenerates nearby allies' health while it stands.",
    sprite = "assets/items/ability_renewal_banner.png",
    type = "ability",
    tags = { "banner", "holy", "restorative" },
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
                -- The 3x3 of Renewing Ground the standard holds open; see ability_rally_banner.lua.
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_renewal", { owner = banner })
                    end
                end
            end
        end,
    },
}
