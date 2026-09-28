-- THE ARC: the Arc's organ (models/storm.lua; "Fire, Lightning, and Dirty Thunder", 2026-09-27). Its two rules
-- beside the fork its bolt carries -- in a creature piece, since a creature carries no shelf stock; the Flashpan and
-- the Static Coil it drops wear the same traits.
--
--   THUNDERCLAP  the first body its lightning strikes each turn is Blinded (trait_thunderclap)
--   STATIC       every tile it walks stores a charge, spent at +3 each on its next bolt (trait_static)
return {
    name = "The Arc",
    description = "Its first bolt each turn inflicts Blind. Every tile it walks stores a charge for its next bolt (+3 each).",
    flavor = "It cannot stand still. Standing still is how it ends.",
    sprite = "assets/items/utility_the_arc.png",
    type = "utility",
    tags = { "natural", "lightning" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_thunderclap", "trait_static" },
}
