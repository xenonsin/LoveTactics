-- A homunculus's natural weapon (the alchemical counterpart to the elementals' Tide/Flame Fists): a
-- clammy, dripping blow that leaves the struck foe Poisoned (data/status/poison.lua). The construct
-- is frail and hits softly, so the toxin is the point -- a homunculus is a shambling poison-ticker
-- that wears a foe down over the turns it survives. `noSteal`: there is nothing here worth pocketing.
local Curve = require("models.curve")

return {
    name = "Homunculus Fists",
    description = "Strikes an adjacent foe and inflicts Poison.",
    flavor = "The construct is frail and hits softly. The toxin does the work, and it has nothing but time.",
    sprite = "assets/items/homunculus_fists.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "poison", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            -- Poison rides the blow: it lands on whoever the strike hits, and only a connecting hit --
            -- the > 0 guard the carried path enforces for free.
            fx.damage(fx.target, { inflicts = "status_poison" })
        end,
    },
}
