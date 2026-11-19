-- An ice elemental's natural weapon. A biting blow of cold, ice-tagged so it feeds on a Frozen or Wet
-- target the way the mage's frost spells do. It does not freeze on its own (that is the Ice Bolt's
-- work) -- an elemental that froze every foe it touched would be too much. `noSteal`: cold you cannot keep.
--
-- IT SPLINTERS THE HEART (the creature identity pass, 2026-11-19): the blow lays Cold-Hearted, the Snow Queen's
-- own splinter (status_cold_hearted -- no heal, buff or aid aimed at an ally; fire thaws it). The elementals are
-- her escort, and this is what makes them HERS: every one left standing is another hand reaching for the
-- company's healing, so they are the bodies to kill before her. Riding the blow (`inflicts`), so the hover
-- names it. A summoned elemental on the company's side lays it on the foe the same way.
local Curve = require("models.curve")

return {
    name = "Frost Fists",
    description = "Batters an adjacent foe with biting cold. Inflicts Cold-Hearted.",
    flavor = "Cold you could never keep, off a thing that has nothing else to give.",
    sprite = "assets/items/frost_fists.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_cold_hearted" })
        end,
    },
}
