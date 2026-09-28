-- STATIC COIL: the Arc's Static (trait_static; "Fire, Lightning, and Dirty Thunder", 2026-09-27), and one of the
-- three things it drops. Each tile you walk stores a charge, to 5; your next lightning cast deals +3 per charge.
-- It asks a caster to move before casting, which casters seldom do -- a Battlemage's, who is already walking in.
return {
    name = "Static Coil",
    description = "Each tile you walk stores a charge (to 5); your next lightning cast deals +3 per charge.",
    flavor = "Every step is a little theft from the ground. It all goes back at once.",
    sprite = "assets/items/utility_static_coil.png",
    type = "utility",
    tags = { "lightning" },
    class = "battlemage",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_static" },
}
