-- Renewal Banner: a mending standard the priest raises on open ground. While it stands, every ally in
-- the 3x3 square around it gains Regeneration (data/status/regen.lua) -- flat health recovered at the
-- start of each of their turns, refreshed while they hold the ground beside it. The restorative cousin
-- of the Rally and Sacred banners: same destructible standard (data/characters/banner.lua), same
-- one-per-relic rule, aimed at an empty tile. See data/items/ability/ability_rally_banner.lua for how
-- the banner and its aura work.
return {
    name = "Renewal Banner",
    description = "Plants a destructible banner granting nearby allies Regeneration while it stands.",
    flavor = "The Cathedral's standard rallies nobody. It simply declines to let them fall.",
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
            -- Forging the standard buys it staying power: +3 health per upgrade level over the
            -- blueprint's base. See ability_rally_banner.lua -- a banner neither moves nor strikes,
            -- so how long it stands is the only thing an upgrade could mean.
            local banner = fx.summon("character_banner", fx.tx, fx.ty, {
                control = "none", timeless = true,
                scaling = { health = 3 }, amount = fx.level,
            })
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
