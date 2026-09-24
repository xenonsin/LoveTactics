-- THE PLUMMET CLOAK: the Wyvern's Stoop, rebuilt for somebody on foot (docs/drops.md -- a mechanic, never
-- a body part). Come a long way before you strike, and the strike carries it: a blow thrown after
-- covering three tiles or more this turn deals a quarter of your Damage more (data/traits/trait_plummet.lua).
--
-- ON THE SKIRMISHER'S SHELF, which the review moved it to (it was pitched as Poacher's): distance is that
-- house's unit of account, and its two neighbours there -- the Outrider's Harness and Running Shot -- pay
-- for the same measure in different coin. A cloth cloak with a little wind turned in its weave, and the
-- square every armour costs.
local Curve = require("models.curve")

return {
    name = "Plummet Cloak",
    description = "A blow thrown after covering three tiles or more this turn deals a quarter of your Damage more.",
    flavor = "Cut to catch the air on the way down. It does nothing whatever on the way up.",
    sprite = "assets/items/armor_plummet_cloak.png",
    type = "armor",
    tags = { "cloth" },
    class = "skirmisher",
    unlockLevel = 2,
    unstocked = true,
    traits = { "trait_plummet" },
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
    resist = { wind = Curve.ramp(1, 11) },
}
