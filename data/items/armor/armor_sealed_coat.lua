-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Holds a seal against one aimed spell and renews it a while after it is spent (trait_sealed_reliquary).
-- status_sealed_ward refuses the next single-target spell outright -- not turned, not reduced: refused.
--
-- The patient sibling of the Mirrorsilk, and the two are a genuine choice rather than a ladder. The
-- Mirrorsilk answers every aimed spell and bills the mana that would otherwise have been a Fireball;
-- this one answers one, costs nothing at all, and then makes the wearer wait. Against a lone enemy
-- caster the coat is strictly better -- it refuses the spell that mattered and the mage keeps a full
-- pool. Against three, it eats the first cantrip and is asleep for the rest of the volley.
--
-- So what the player is really choosing between is a resource and a clock, which is the same decision
-- the whole Arcanum shelf keeps asking. Pride can afford to pay; pride cannot afford to wait.
--
-- utility_sealed_reliquary carries the same rule in a cell.
--
-- Cloth: a square of pace.
local Curve = require("models.curve")

return {
    name = "The Sealed Coat",
    description = "Holds a seal against one aimed spell, and renews after it is spent.",
    flavor = "The Arcanum stitches the seal shut and considers the question of what is inside settled.",
    sprite = "assets/items/armor_sealed_coat.png",
    type = "armor",
    tags = { "cloth", "arcane" },
    class = "mage",
    dropTier = 7,
    traits = { "trait_sealed_reliquary" },
    bonus = { magicDefense = Curve.ramp(4, 14), movement = -1 },
    resist = { magical = 2 },
}
