-- A coin-chitter's nip: it takes coin, not health.
--
-- The Greed circle's swarm weapon. What it costs you is real campaign gold (fx.bounty), which is the one
-- resource in the game that does not come back at the end of the fight -- and the chitter runs for the
-- dark afterwards, so chasing it is a decision about whether the coin is worth the tempo.
--
-- Deliberately modest. A swarm that emptied a purse would make the circle a tax rather than a fight; the
-- point is that it adds up, and that the Assayer standing behind it is reading the total.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Cutpurse Nip",
    description = "Nips an adjacent foe and takes coin from it.",
    flavor = "It has no use for money. It has a very firm opinion about who else should have it.",
    sprite = "assets/items/cutpurse_nip.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 3 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            fx.damage(fx.target)
            fx.bounty(6 + fx.level)
        end,
    },
}
