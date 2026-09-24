    -- SNOWSLIDE: one of the Glacier King's own. What the Snowbank has been saving, spent in one blow
-- (status_empowered, +4 per stack). Needs a Snowbank to be anything.
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Snowslide",
        description = "Spend all your Snowbank for +4 Damage per stack on your next hit.",
        flavor = "It was only ever waiting to fall.",
        sprite = "assets/items/utility_snowslide.png",
        type = "utility",
        class = "knight",
        unlockLevel = 10,
        unstocked = true,
        tags = { "offensive" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        effect = function(fx)
            local bank = require("models.status").get(fx.user, "status_snowbank")
            local stacks = bank and bank.magnitude or 0
            if stacks <= 0 then return end
            fx.applyStatus(fx.user, "status_empowered", { magnitude = 4 * stacks })
            bank.magnitude = 0
        end,
    },
    }
