-- Invocation: the mage half of the Theurge (mage x priest). A channelled miracle -- the caster winds up
-- for several ticks (exposed while it builds), then calls down holy fire on a diamond of ground. It
-- routes as MAGICAL and carries `holy`, so demonic flesh dreads it most. The Theurge's mechanic in one
-- word: pride's channel spent on the priest's judgment, a bigger blessing for the longer wait.
local Curve = require("models.curve")

return {
    name = "Invocation",
    description = "Channeled: sears enemies in area.",
    flavor = "The longer the prayer, the fewer the words needed at the end of it.",
    sprite = "assets/items/ability_invocation.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "theurge", -- mage x priest; the Channelled-miracle mechanic's first stock
    price = 575,
    unlockQuests = 6,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 5,
        windup = 4, -- winds up before it fires (Combat reads `windup`; see ability_meteor_storm)
        cost = { stat = "mana", amount = 14 },
        aoe = { radius = 1, shape = "diamond" },
        damage = Curve.ramp(12, 22), -- carries `holy` + `magical` via tags
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
