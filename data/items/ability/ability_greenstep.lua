-- Greenstep: step into your own grove and out of it beside any plant of yours within six tiles.
--
-- The Nymph's escape, handed over with the aim put back in the caster's hands: she always steps as far
-- from her pursuers as her grove allows (weapon_greenstep), and a company picks its own tile. The tile
-- must be free and beside one of the caster side's plants -- a sapling, a hedge, a thorn floor, a tree
-- (models/grove.lua) -- and a tile that is not is refused rather than wasted, so the aim is the check.
return {
    name = "Greenstep",
    description = "Teleport to a free tile beside one of your plants, up to 6 tiles away.",
    flavor = "She was never in front of you. You were looking at the tree.",
    sprite = "assets/items/ability_greenstep.png",
    type = "ability",
    tags = { "nature", "movement" },
    class = "druid",
    price = 300,
    unlockLevel = 5,
    activeAbility = {
        target = "tile",
        range = 6,
        speed = 3,
        support = true,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            local Grove = require("models.grove")
            local ok = false
            for _, e in ipairs(Grove.exits(fx.combat, fx.user.side)) do
                if e.x == fx.tx and e.y == fx.ty then ok = true break end
            end
            if not ok then
                fx.log("action", "There is nothing of yours growing there to step out of.")
                return
            end
            fx.teleportUser(fx.tx, fx.ty)
        end,
    },
}
