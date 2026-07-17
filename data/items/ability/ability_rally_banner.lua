-- Rally Banner: the knight drives a standard into open ground, and it fights for the party by simply
-- STANDING. While it stands, every ally in the 3x3 square around it is Inspired (data/status/inspiration.lua)
-- -- courage in the swing and the shield, a lift to Damage and Defense refreshed each round. The banner
-- is a real, destructible body (data/characters/banner.lua): the enemy can knock it over to end the
-- rally, and it holds only one banner per relic (recasting is refused while the last still stands).
--
-- A ground-target support cast: aim an empty tile in range and the standard rises there. The rally
-- persists until the banner falls -- no duration -- so plant it where the line will hold, not where it
-- is about to break. Compare its siblings, which raise the same standard to spread other graces:
-- data/items/ability/ability_sacred_banner.lua (Blessing) and ability_renewal_banner.lua (Regeneration).
return {
    name = "Rally Banner",
    description = "Plants a destructible banner that Inspires nearby allies while it stands.",
    flavor = "It fights by standing. Plant it where the line will hold, not where it is breaking.",
    sprite = "assets/items/ability_rally_banner.png",
    type = "ability",
    tags = { "banner", "rally" },
    class = "fighter",
    price = 320,
    repRank = 3,
    activeAbility = {
        target = "tile", -- aim an empty tile; the standard rises there
        range = 3,
        speed = 5,
        support = true, -- a friendly cast: reads green, and the AI treats it so
        cost = { stat = "stamina", amount = 12 },
        effect = function(fx)
            local banner = fx.summon("character_banner", fx.tx, fx.ty, { control = "none", timeless = true })
            if banner and banner.alive then
                -- The rally IS the ground, not the banner: lay the 3x3 square of Rally zone
                -- (data/hazards/hazard_rally.lua) and hand each tile to the banner as its owner, so the
                -- whole square lifts the moment the standard falls. Tiles that can't hold a zone (a
                -- wall, off the map) are skipped by Hazard.place returning nil.
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_rally", { owner = banner })
                    end
                end
            end
        end,
    },
}
