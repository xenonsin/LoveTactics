-- THE WRITHING MASS: what is wearing the boar once the iron finally wins.
--
-- The Unseeing's first weapon, arriving half a fight late (character_the_turning). It is deliberately
-- unremarkable as a damage number -- a tier-3 apex's blow and nothing more -- because the thing it does
-- is not the damage. It inflicts status_unclosing_wound: the cut will not knit, and NOTHING heals a body
-- wearing it, by any means, for as long as it holds (Combat.applyHeal refuses at the top).
--
-- THE HALF OF THE CURSE YOU CANNOT WALK OUT OF. His ground (data/hazards/hazard_curse.lua) grants
-- status_cursed, which is ZONE-BOUND: it eats at a body and refuses to let it be healed, and both halves
-- stop the moment that body steps off the tile. Walking out has always been the answer to this fight.
-- This is the beat where walking out stops being enough -- the blow puts the refusal IN you, carried,
-- ageing on its own clock, with no tile to leave.
--
-- It is deliberately the smaller of the two statuses rather than a third thing nobody has seen. A player
-- who has learned what his floor does already knows most of what this means, and the difference between
-- them -- ground you can leave, a wound you cannot -- is the whole reading of the second phase.
--
-- `inflicts` rides INSIDE the damage call rather than being applied beside it, which is what makes it
-- land as part of the blow -- warded by a barrier that eats the hit, answered by the target's own
-- statusResist, and quoted by the aim preview as one event rather than two.
local Curve = require("models.curve")

return {
    name = "Writhing Mass",
    description = "A blow that will not close.",
    flavor = "The boar is somewhere underneath. This is not the boar.",
    sprite = "assets/items/weapon_writhing_mass.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "dark" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(14, 24),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = { id = "status_unclosing_wound" } })
        end,
    },
}
