-- Lifted off the Anvil, and it is the brake Ira never had.
--
-- THE SECOND HALF OF A CIRCLE'S PAYMENT. A general pays the piece she was carrying; her lieutenant pays
-- this. What makes them a PAIR rather than a big one and a small one is that this reads the number the
-- other one is generating: the Mail of the Unappeased buys damage with the health you are missing, and
-- the Anvil's Face spends that same rage on staying upright (data/traits/trait_anvil_face.lua).
--
-- Ira could afford an engine with no brake. A four-body company cannot, so the Mail alone turns every
-- build around it into "win before the rage matters". With this on, the rage is what keeps you standing
-- long enough for the rage to matter.
--
-- IT WORKS ALONE. Without the Mail it is still a plate that gets harder to chip the longer it is being
-- chipped, which is the answer to a swarm and worth carrying off the Anvil's floor before you have ever
-- seen Ira.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
--
-- No `flavor` fragment naming the Gate Below. There are exactly seven of those and they belong to the
-- generals' relics (docs/item-text.md); a lieutenant's piece is kit, not a piece of the map.
local Curve = require("models.curve")

return {
    name = "The Anvil's Face",
    description = "Hardens with every blow you take, and faster while Rising Wrath is on you.",
    flavor = "The Colosseum threw the Anvil out for being too slow to kill anyone. This is the part " ..
        "that did the work.",
    sprite = "assets/items/anvils_face.png",
    type = "utility",
    class = "creature",
    dropTier = 6,
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off the body
    traits = { "trait_anvil_face" },
    bonus = { defense = Curve.ramp(2, 12) },
}
