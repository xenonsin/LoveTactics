-- Taproot: the Mandrake's one reach, and the Alraune line's HOLD.
--
-- A root comes up through the floor under a body up to three tiles off and holds it where it stands --
-- `status_root`, the same six ticks the Lamia's knot leaves. The difference is where: the knot holds a
-- body beside the serpent, and this holds it wherever it already was, which is usually on the honey.
--
-- WHICH IS WHY THE LINE IS IN THE HOLD HALF OF THE CIRCLE. Root sets `blocksForcedMove`, so a rooted body
-- cannot be shoved by anybody -- and the Lust circle never fields a rooter beside a shover
-- (Descent.SINS' Lust entry, pinned by tests/greed_lust_circle_spec.lua). A Mandrake shares its fights
-- with the Alraune, the Lamiae and the mushroom folk, and never with the flock.
--
-- MAGICAL, AND IT IS THE CAST THAT BURNS. A demon's natural blow carries fire (docs/bestiary.md), and
-- this is not a blow -- it is the pit's own root -- so it rides the magic channel and the earth. The
-- root rides INSIDE the hit (`inflicts`), so a miss takes it with the wound (docs/accuracy.md).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Taproot",
    description = "A root comes up under a foe up to 3 tiles away and leaves Root.",
    flavor = "It does not pull you down. It only makes sure you are still here when she arrives.",
    sprite = "assets/items/taproot.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "earth", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_root" })
        end,
    },
}
