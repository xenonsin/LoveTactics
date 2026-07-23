-- Invocation: the mage half of the Theurge (mage x priest). A channelled miracle -- the caster winds up
-- for several ticks (exposed while it builds), then calls down holy fire on a diamond of ground. It
-- routes as MAGICAL and carries `holy`, so demonic flesh dreads it most. The Theurge's mechanic in one
-- word: pride's channel spent on the priest's judgment, a bigger blessing for the longer wait.
return {
    name = "Invocation",
    description = "Winds up, then calls down holy fire on an area. Channelled: disrupted by hard control.",
    flavor = "The longer the prayer, the fewer the words needed at the end of it.",
    sprite = "assets/items/ability_invocation.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "mage",
    discipline = "theurge", -- mage x priest; the Channelled-miracle mechanic's first stock
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 5,
        channel = 4, -- winds up before it fires (Combat reads ab.channel; see ability_meteor_storm)
        cost = { stat = "mana", amount = 14 },
        aoe = { radius = 1, shape = "diamond" },
        damage = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }, -- carries `holy` + `magical` via tags
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
