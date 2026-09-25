-- MITHRIL SHIRT: the Hoard-Thane's own trophy (round 3, 2026-09-24), and the one armor in the game that
-- costs no movement. Every dwarf hall owes one mithril coat -- the one that turned the troll's spear in
-- Moria -- and Keno's call on it was plain: "have mythril be armor and cost no movement, just add more
-- effects to make it special".
--
-- SO IT IS THE NAMED EXCEPTION to the rule every other coat obeys (docs/classes.md: every armor costs a
-- square). tests/armor_spec.lua carries it on a list of one, with this reason, so the exception cannot
-- spread by accident. What makes it worth breaking the rule for, all four from the same coat:
--   Light as a feather   no movement cost
--   Hard as dragon-scale Pierce resist -- the spearpoint turned
--   Never a critical     no blow against the wearer is ever a critical, rolled or forced (`critProof`)
--   The troll's spear    once a fight, a blow that would kill the wearer leaves it at 1 health
--                        (`revivesOnLethal`, Second Wind's own rule, at a sliver)
-- The last two ride trait_mithril.
--
-- An unstocked trophy: on the rack, never sold (tests/discovery_spec.lua's named TROPHIES). Knight's
-- shelf, as the coat that armours the body.
local Curve = require("models.curve")

return {
    name = "Mithril Shirt",
    description = "Costs no movement. No blow against you is a critical, and once a fight a killing blow leaves you at 1.",
    flavor = "Light as a feather, and hard as dragon-scales. Worth more than the Shire and everything in it.",
    sprite = "assets/items/armor_mithril_shirt.png",
    type = "armor",
    tags = { "light" },
    class = "knight",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_mithril" },
    bonus = { defense = Curve.ramp(4, 14), movement = 0 },
    resist = { pierce = 3 },
}
