-- Brace: the knight's first lesson, and the ability a body is handed when it unlocks the Knight
-- (docs: the class-unlock design, 2026-10-15). The caster takes the Defending stance and lends it to the
-- ally beside it -- both at +6 Defense, both until the CASTER's next turn.
--
-- WHY IT IS DEFENDING AND NOT A NEW STATUS. A shield's Defend already raises exactly this stance
-- (data/status/status_defending.lua), and a knight teaching a second, differently-named brace would be
-- two words for one mechanic. The lent half rides the stamp the Sloth Tollkeepers' barrier proved: the
-- ally's brace carries `heldBy = caster`, which holds it past the ally's own turn start, and the
-- caster's own brace takes every brace it lent down as the caster's next turn opens.
--
-- An ally already braced on its own and harder (a tower shield's Defend) keeps what it had, which is
-- the barrier's rule too: a lend never lowers a guard.
--
-- Cast on yourself it is a Defend that does not end the turn by waiting -- you can still have moved.
local BRACE = 6

return {
    name = "Brace",
    description = "You and an adjacent ally take the Defending stance until your next turn.",
    flavor = "The Bastion's first drill: shoulder to shoulder, and nobody steps back alone.",
    sprite = "assets/items/ability_brace.png",
    type = "ability",
    tags = { "protective" },
    class = "knight",
    price = 125,
    unlockLevel = 1,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 1,
        speed = 2,
        support = true,
        cost = { stat = "stamina", amount = 10 },
        description = "+6 Defense to you and the ally until your next turn.",
        effect = function(fx)
            local Status = require("models.status")
            local own = fx.applyStatus(fx.user, "status_defending", { magnitude = BRACE })
            -- Your own stance is yours: a brace somebody else lent you ends at YOUR next turn now.
            if own then own.heldBy = nil end
            local ally = fx.target
            if not ally or ally == fx.user then return end
            local had = Status.get(ally, "status_defending")
            if had and not had.heldBy and (had.magnitude or 0) >= BRACE then return end
            local lent = fx.applyStatus(ally, "status_defending", { magnitude = BRACE })
            if lent then lent.heldBy = fx.user end
        end,
    },
}
